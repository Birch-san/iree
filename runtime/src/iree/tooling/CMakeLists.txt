################################################################################
# Autogenerated by build_tools/bazel_to_cmake/bazel_to_cmake.py from           #
# runtime/src/iree/tooling/BUILD                                               #
#                                                                              #
# Use iree_cmake_extra_content from iree/build_defs.oss.bzl to add arbitrary   #
# CMake-only content.                                                          #
#                                                                              #
# To disable autogeneration for this file entirely, delete this header.        #
################################################################################

iree_add_all_subdirs()

iree_cc_library(
  NAME
    cpu_features
  HDRS
    "cpu_features.h"
  SRCS
    "cpu_features.c"
  DEPS
    iree::base
    iree::base::target_platform
  PUBLIC
)

iree_cc_library(
  NAME
    device_util
  HDRS
    "device_util.h"
  SRCS
    "device_util.c"
  DEPS
    iree::base
    iree::base::internal::flags
    iree::base::internal::synchronization
    iree::base::tracing
    iree::hal
    iree::hal::drivers
  PUBLIC
)

iree_cc_library(
  NAME
    numpy_io
  HDRS
    "numpy_io.h"
  SRCS
    "numpy_io.c"
  DEPS
    iree::base
    iree::base::tracing
    iree::hal
  PUBLIC
)

iree_cc_test(
  NAME
    numpy_io_test
  SRCS
    "numpy_io_test.cc"
  DEPS
    ::device_util
    ::numpy_io
    iree::base::internal::file_io
    iree::testing::gtest
    iree::testing::gtest_main
    iree::tooling::testdata::npy
)

iree_cc_library(
  NAME
    vm_util
  HDRS
    "vm_util.h"
  SRCS
    "vm_util.cc"
  DEPS
    ::numpy_io
    iree::base
    iree::base::cc
    iree::base::internal::span
    iree::base::logging
    iree::base::tracing
    iree::hal
    iree::modules::hal
    iree::vm
    iree::vm::bytecode_module
    iree::vm::cc
  PUBLIC
)

iree_cc_test(
  NAME
    vm_util_test
  SRCS
    "vm_util_test.cc"
  DEPS
    ::device_util
    ::vm_util
    iree::base
    iree::hal
    iree::modules::hal
    iree::testing::gtest
    iree::testing::gtest_main
    iree::vm
    iree::vm::cc
)

# libyaml does not build cleanly on bare-metal systems
if(IREE_ENABLE_THREADING)

iree_cc_library(
  NAME
    trace_replay
  HDRS
    "trace_replay.h"
  SRCS
    "trace_replay.c"
  DEPS
    ::yaml_util
    iree::base
    iree::base::internal::file_io
    iree::base::internal::path
    iree::base::tracing
    iree::hal
    iree::modules::hal
    iree::vm
    iree::vm::bytecode_module
    yaml
  PUBLIC
)

iree_cc_library(
  NAME
    yaml_util
  HDRS
    "yaml_util.h"
  SRCS
    "yaml_util.c"
  DEPS
    iree::base
    yaml
  PUBLIC
)

endif()

### BAZEL_TO_CMAKE_PRESERVES_ALL_CONTENT_BELOW_THIS_LINE ###
