# Examples

# Using kind (Kubernetes-in-Docker)

With a kind cluster created in your machine, build and load the images with:

```
bazel build //:examples && bazel run //:examples.kind_load_images
```

Then install the helm chart, replacing `<redis_url>` with a URL (it won't try to connect), then
check in the logs that the service printed the url to the terminal:

```
bazel run @sh_helm_helm_v3//cmd/helm -- install examples "$(pwd)/bazel-bin/examples.tgz" \
    --set talkie_services.helloworld.secrets.redis.url=<redis_url>
```
