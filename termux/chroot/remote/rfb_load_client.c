#include <rfb/rfbclient.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static volatile sig_atomic_t running = 1;
static unsigned long updates;

static void stop_client(int sig) {
    (void)sig;
    running = 0;
}

static char *get_password(rfbClient *client) {
    (void)client;
    return rfbDecryptPasswdFromFile("/root/.vnc/passwd");
}

static rfbBool allocate_framebuffer(rfbClient *client) {
    free(client->frameBuffer);
    client->frameBuffer = calloc((size_t)client->width * client->height,
                                 client->format.bitsPerPixel / 8);
    return client->frameBuffer != NULL;
}

static void got_update(rfbClient *client, int x, int y, int w, int h) {
    (void)client; (void)x; (void)y; (void)w; (void)h;
    updates++;
}

int main(int argc, char **argv) {
    int seconds = argc > 1 ? atoi(argv[1]) : 15;
    int compression = argc > 2 ? atoi(argv[2]) : 2;
    int quality = argc > 3 ? atoi(argv[3]) : 6;
    char *client_argv[] = {"rfb-load-client", "127.0.0.1:0", NULL};
    int client_argc = 2;
    time_t deadline = time(NULL) + (seconds > 0 ? seconds : 15);
    rfbClient *client = rfbGetClient(8, 3, 4);
    if (client == NULL) return 2;
    client->GetPassword = get_password;
    client->MallocFrameBuffer = allocate_framebuffer;
    client->GotFrameBufferUpdate = got_update;
    client->canHandleNewFBSize = TRUE;
    client->appData.encodingsString = "tight copyrect";
    client->appData.compressLevel = compression;
    client->appData.qualityLevel = quality;
    client->appData.enableJPEG = TRUE;
    signal(SIGINT, stop_client);
    signal(SIGTERM, stop_client);
    if (!rfbInitClient(client, &client_argc, client_argv)) return 3;
    while (running && time(NULL) < deadline) {
        int ready = WaitForMessage(client, 100000);
        if (ready < 0 || (ready > 0 && !HandleRFBServerMessage(client))) break;
    }
    printf("updates=%lu size=%dx%d\n", updates, client->width, client->height);
    rfbClientCleanup(client);
    return 0;
}
