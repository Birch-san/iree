# Copyright 2020 The IREE Authors
#
# Licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

load("//build_tools/bazel:build_defs.oss.bzl", "iree_compiler_cc_library")

package(
    default_visibility = ["//visibility:public"],
    features = ["layering_check"],
    licenses = ["notice"],  # Apache 2.0
)

iree_compiler_cc_library(
    name = "Conversion",
    srcs = [
        "ConversionPatterns.cpp",
    ],
    hdrs = [
        "ConversionPatterns.h",
    ],
    deps = [
        "//compiler/src/iree/compiler/Dialect/HAL/Conversion",
        "//compiler/src/iree/compiler/Dialect/Modules/Check/IR",
        "//compiler/src/iree/compiler/Dialect/VM/Conversion",
        "@llvm-project//mlir:Pass",
        "@llvm-project//mlir:Transforms",
    ],
)
