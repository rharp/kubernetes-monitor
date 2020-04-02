#---------------------------------------------------------------------
# STAGE 1: Build skopeo inside a temporary container
#---------------------------------------------------------------------
FROM golang:1.13.1-alpine3.10 AS skopeo-build

RUN apk --no-cache add git make gcc musl-dev ostree-dev go-md2man
RUN git clone --depth 1 -b 'v0.1.39' https://github.com/containers/skopeo $GOPATH/src/github.com/containers/skopeo
RUN cd $GOPATH/src/github.com/containers/skopeo \
  && make binary-local-static DISABLE_CGO=1 \
  && make install

#---------------------------------------------------------------------
# STAGE 2: Build the kubernetes-monitor
#---------------------------------------------------------------------
# FROM node:erbium-alpine
FROM registry.redhat.io/ubi8/nodejs-12

# LABEL maintainer="Snyk Ltd"
LABEL maintainer="Snyk Ltd" \
      name="kubernetes-monitor" \
      vendor="Snyk Ltd" \
      version="1.25.0" \
      release="1" \
      summary="Container to monitor Kubernetes clusters' security" \
      description="Snyk integrates with Kubernetes, enabling you to import and test your running workloads and identify vulnerabilities in their associated images and configurations that might make those workloads less secure."

COPY LICENSE /licenses/LICENSE

ENV NODE_ENV production

# RUN apk update
# RUN apk upgrade
# RUN apk --no-cache add db dumb-init
RUN yum update --disablerepo=* --enablerepo=ubi-8-appstream --enablerepo=ubi-8-baseos -y && rm -rf /var/cache/yum
RUN yum install --disablerepo=* --enablerepo=ubi-8-appstream --enablerepo=ubi-8-baseos db dumb-init -y && rm -rf /var/cache/yum

RUN addgroup -S -g 10001 snyk
RUN adduser -S -G snyk -h /srv/app -u 10001 snyk

WORKDIR /srv/app
USER 10001:10001

COPY --chown=snyk:snyk --from=skopeo-build /usr/bin/skopeo /usr/bin/skopeo
COPY --chown=snyk:snyk --from=skopeo-build /etc/containers/registries.d/default.yaml /etc/containers/registries.d/default.yaml
COPY --chown=snyk:snyk --from=skopeo-build /etc/containers/policy.json /etc/containers/policy.json

# Add manifest files and install before adding anything else to take advantage of layer caching
ADD --chown=snyk:snyk package.json package-lock.json .snyk ./

RUN npm install

# add the rest of the app files
ADD --chown=snyk:snyk . .

# Complete any `prepare` tasks (e.g. typescript), as this step ran automatically prior to app being copied
RUN npm run prepare

ENTRYPOINT ["/usr/bin/dumb-init", "--", "bin/start"]
