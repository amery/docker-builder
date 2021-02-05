# docker-builder

## `docker-builder` runner

https://github.com/amery/docker-builder/blob/master/docker/run.sh

### Environment

| Variable             | Purpose
|----------------------|-----------------------------------------------------------
| `DOCKER_DIR`         | `${DOCKER_DIR}/Dockerfile`
| `DOCKER_ID`          | optional image id to use instead of building `DOCKER_DIR`
| `DOCKER_RUN_ENV`     | variables to passthrough if defined
| `DOCKER_RUN_VOLUMES` | variables that specify extra directories to mount
| `DOCKER_EXTRA_OPTS`  | extra options to pass as-is to `docker run`
