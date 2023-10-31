PKGNAME:=unifi
TAG:=master
DOCKERFILE:=Dockerfile

.PHONY: build push

build:
	docker build --pull -t $(PKGNAME):$(TAG) -f $(DOCKERFILE) .
