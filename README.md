# mockingbird

## Build

Copy `Mockingbird_Sandbox.ova` into the current directory and run `build.sh`.

Set `IMAGE_UPLOAD_PATH` environment variable to override desination registry path for uploaded containerDisk.

## Deploy

```
kubectl apply -f mockingbird-sandbox.yaml
```

Ports 22, 80, and 8090 are exposed via a Kubernetes Service.
