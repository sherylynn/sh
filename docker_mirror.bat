docker-machine stop default
docker-machine rm default
docker-machine create --engine-registry-mirror=zbhkub6p.mirror.aliyuncs.com -d virtualbox default
docker-machine env default
eval "$(docker-machine env default)"
docker info