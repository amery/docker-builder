HOME/bin/x       -> WS/xxx/bin/x
WS/run.sh        -> WS/xxx/app-builder/docker-run.sh
                    WS/xxx/app-builder/run.sh
WS/docker-run.sh -> WS/xxx/chosen-docker/run.sh

1. WS/xxx/yyy$ x cmd
2. WS/xxx/yyy$ WS/run.sh cmd
3. WS/xxx/yyy$ WS/docker-run.sh WS/xxx/app-builder/run.sh cmd
4. WS/xxx/yyy$ WS/xxx/chosen-docker/run.sh WS/xxx/app-builder/run.sh cmd
