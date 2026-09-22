#!/usr/bin/env python3
"""Android Firefox Remote Debugger CLI for the chroot environment.

这个脚本直接连接 Android Firefox 暴露的 abstract Unix socket，不依赖 adb。
适用于“Firefox 跑在 Android，调试客户端跑在同一台手机的 chroot Linux”场景。

默认 socket:
    @org.mozilla.firefox/firefox-debugger-socket

常用:
    firefox_remote_debug.py tabs
    firefox_remote_debug.py eval 'document.title'
    firefox_remote_debug.py eval --tab 1 'location.href'
    firefox_remote_debug.py query 'main'
    firefox_remote_debug.py query '[data-testid="foo"]'
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import sys
from typing import Any

DEFAULT_SOCKET = "org.mozilla.firefox/firefox-debugger-socket"


class FirefoxRDP:
    def __init__(self, socket_name: str, timeout: float = 3.0):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        # Linux abstract namespace 的 Python 表示法：首字节为 NUL。
        self.sock.connect("\0" + socket_name)
        self.hello = self.recv_packet()

    def close(self) -> None:
        self.sock.close()

    def send_packet(self, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        self.sock.sendall(str(len(data)).encode("ascii") + b":" + data)

    def recv_packet(self) -> dict[str, Any]:
        length = bytearray()
        while True:
            one = self.sock.recv(1)
            if not one:
                raise RuntimeError("Firefox 调试连接已关闭")
            if one == b":":
                break
            length.extend(one)

        expected = int(length.decode("ascii"))
        data = bytearray()
        while len(data) < expected:
            chunk = self.sock.recv(expected - len(data))
            if not chunk:
                raise RuntimeError("Firefox 调试报文被截断")
            data.extend(chunk)
        return json.loads(data.decode("utf-8"))

    def request(self, actor: str, packet_type: str, **kwargs: Any) -> dict[str, Any]:
        self.send_packet({"to": actor, "type": packet_type, **kwargs})
        while True:
            packet = self.recv_packet()
            # Firefox 会异步穿插 frameUpdate 等事件；只返回目标 actor 的响应。
            if packet.get("from") == actor:
                return packet

    def list_tabs(self) -> list[dict[str, Any]]:
        packet = self.request("root", "listTabs")
        return packet.get("tabs", [])

    def tab(self, index: int | None) -> dict[str, Any]:
        tabs = self.list_tabs()
        if not tabs:
            raise RuntimeError("Firefox 当前没有可调试标签页")
        if index is not None:
            if index < 0 or index >= len(tabs):
                raise RuntimeError(f"标签页索引越界：{index}，当前共 {len(tabs)} 个")
            return tabs[index]

        # 默认优先普通网页；about:blank 通常是调试产生的临时页。
        for tab in tabs:
            if not str(tab.get("url", "")).startswith("about:blank"):
                return tab
        return tabs[0]

    def target(self, tab: dict[str, Any]) -> dict[str, Any]:
        packet = self.request(tab["actor"], "getTarget")
        frame = packet.get("frame")
        if not isinstance(frame, dict):
            raise RuntimeError(f"无法取得标签页 target：{packet}")
        return frame

    def evaluate(self, expression: str, tab_index: int | None = None) -> Any:
        tab = self.tab(tab_index)
        target = self.target(tab)
        console = target["consoleActor"]

        self.send_packet({"to": console, "type": "evaluateJSAsync", "text": expression})
        result_id = None
        while True:
            packet = self.recv_packet()
            if packet.get("from") != console:
                continue
            if "resultID" in packet and packet.get("type") != "evaluationResult":
                result_id = packet["resultID"]
                continue
            if packet.get("type") == "evaluationResult":
                if result_id is not None and packet.get("resultID") != result_id:
                    continue
                if packet.get("hasException"):
                    raise RuntimeError(str(packet.get("exceptionMessage") or packet.get("exception") or packet))
                return self.resolve_grip(packet.get("result"))

    def resolve_grip(self, value: Any) -> Any:
        """解析 Firefox RDP 的常见 grip；尤其处理超过阈值的 longString。"""
        if isinstance(value, dict) and value.get("type") == "longString":
            actor = value.get("actor")
            length = int(value.get("length") or 0)
            initial = value.get("initial") or ""
            if not actor or len(initial) >= length:
                return initial
            packet = self.request(actor, "substring", start=len(initial), end=length)
            return initial + str(packet.get("substring") or "")
        return value


def print_value(value: Any) -> None:
    if isinstance(value, (dict, list)):
        print(json.dumps(value, ensure_ascii=False, indent=2))
    elif value is None:
        print("null")
    else:
        print(value)


def main() -> int:
    parser = argparse.ArgumentParser(description="直接调试同机 Android Firefox")
    parser.add_argument(
        "--socket",
        default=os.environ.get("FIREFOX_DEBUG_SOCKET", DEFAULT_SOCKET),
        help="Firefox abstract debugger socket 名称",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("tabs", help="列出 Firefox 标签页")

    eval_parser = sub.add_parser("eval", help="在指定标签页执行 JavaScript")
    eval_parser.add_argument("--tab", type=int, default=None)
    eval_parser.add_argument("expression")

    query_parser = sub.add_parser("query", help="查询 DOM 元素并返回摘要")
    query_parser.add_argument("--tab", type=int, default=None)
    query_parser.add_argument("selector")

    html_parser = sub.add_parser("html", help="读取页面 HTML")
    html_parser.add_argument("--tab", type=int, default=None)
    html_parser.add_argument("--selector", default="html")

    args = parser.parse_args()

    try:
        client = FirefoxRDP(args.socket)
    except Exception as exc:
        print(f"连接 Android Firefox 失败：{exc}", file=sys.stderr)
        print("请确认 Firefox > 设置 > 高级 > 通过 USB 远程调试 已开启。", file=sys.stderr)
        return 2

    try:
        if args.command == "tabs":
            tabs = client.list_tabs()
            for index, tab in enumerate(tabs):
                selected = "*" if tab.get("selected") else " "
                title = tab.get("title") or "(无标题)"
                print(f"{selected}[{index}] {title}")
                print(f"    {tab.get('url', '')}")
            return 0

        if args.command == "eval":
            print_value(client.evaluate(args.expression, args.tab))
            return 0

        if args.command == "query":
            selector = json.dumps(args.selector, ensure_ascii=False)
            expression = f"""(() => {{
                const e = document.querySelector({selector});
                if (!e) return null;
                const r = e.getBoundingClientRect();
                return JSON.stringify({{
                    tag: e.tagName,
                    id: e.id,
                    className: typeof e.className === 'string' ? e.className : '',
                    text: (e.innerText || e.textContent || '').slice(0, 2000),
                    outerHTML: e.outerHTML.slice(0, 8000),
                    rect: {{x:r.x,y:r.y,width:r.width,height:r.height}}
                }});
            }})()"""
            result = client.evaluate(expression, args.tab)
            if isinstance(result, str):
                try:
                    print(json.dumps(json.loads(result), ensure_ascii=False, indent=2))
                except json.JSONDecodeError:
                    print(result)
            else:
                print_value(result)
            return 0

        if args.command == "html":
            selector = json.dumps(args.selector, ensure_ascii=False)
            expression = f"document.querySelector({selector})?.outerHTML ?? null"
            print_value(client.evaluate(expression, args.tab))
            return 0

        return 1
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
