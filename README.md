# Talkie

Talkie is a framework for developing Microservices in Go. It leverages Bazel to
abstract and generate boilerplate code involved in a Microservice system.

Part of this is accomplished by generating the main entrypoint of the
Microservice, requesting from the user a gRPC service definition (the Proto
library) and the gRPC service implementation (the Go library).

Common features (e.g. tracing and logging) can all be injected from this main
entrypoint. Images and deployment manifests can also be generated from this
framework. These opinionated features make the overall system consistent,
focusing on the developer productivity implementing the business logic of the
system instead of dealing with toil work.

See the [examples](./examples) directory for a glimpse of how to use this
framework.

To update go targets and dependencies, make the required changes to the go files (import and use), then run:

```
bazel run tidy
```

To find all targets available from a talkie macro, run:

```
bazel query //{talkie macro folder name}:all
```

ex:

```
bazel query //examples/helloworld_http:all
```

should see response similar to:

```
//examples/helloworld_http:helloworld_http_client
//examples/helloworld_http:helloworld_http_entrypoints
//examples/helloworld_http:helloworld_http
```

then, you can run the server to start the service:

```
bazel run //examples/helloworld_http
```

This will start the service and expose all the endpoints as you created them.
