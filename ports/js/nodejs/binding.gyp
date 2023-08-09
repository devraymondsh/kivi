{
  "targets": [
    {
      "target_name": "kivi-nodejs",
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "sources": [ "main.cpp" ],
      "libraries": [ "../../../../core/zig-out/lib/libkivi.a" ],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")"
      ],
      'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ],
    }
  ]
}