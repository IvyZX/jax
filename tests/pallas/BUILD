# Copyright 2023 The JAX Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(
    "//jaxlib:jax.bzl",
    "jax_generate_backend_suites",
    "jax_test",
    "py_deps",
)

licenses(["notice"])

package(
    default_applicable_licenses = [],
    default_visibility = ["//visibility:private"],
)

jax_generate_backend_suites()

jax_test(
    name = "pallas_test",
    srcs = [
        "pallas_test.py",
    ],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_p100",
        "gpu_p100_x32",
    ],
    enable_configs = [
        "gpu_a100_x32",
        "gpu_h100_x32",
    ],
    shard_count = {
        "cpu": 8,
        "gpu": 4,
        "tpu": 4,
    },
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",
        "//jax:pallas_gpu_ops",
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy"),
)

jax_test(
    name = "pallas_jumble_test",
    srcs = [
        "pallas_jumble_test.py",
    ],
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_a100",
        "gpu_p100",
        "gpu_p100_x32",
        "gpu_h100",
    ],
    shard_count = {
        "tpu": 1,
    },
    deps = [
        "//jax:pallas",
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy"),
)

jax_test(
    name = "ops_test",
    srcs = [
        "ops_test.py",
    ],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_p100",
        "gpu_p100_x32",
    ],
    enable_configs = [
        "gpu_a100",
        "gpu_a100_x32",
        "gpu_h100",
        "gpu_h100_x32",
    ],
    shard_count = {
        "cpu": 8,
        "gpu": 8,
        "tpu": 8,
    },
    tags = [
        "noasan",  # Times out.
        "nomsan",  # Times out.
        "notsan",  # Times out.
    ],
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",  # build_cleaner: keep
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("hypothesis") + py_deps("numpy"),
)

jax_test(
    name = "indexing_test",
    srcs = [
        "indexing_test.py",
    ],
    disable_backends = [
        "gpu",
    ],
    tags = [
        "noasan",  # Times out.
        "nomsan",  # Times out.
        "notsan",  # Times out.
    ],
    deps = [
        "//jax:pallas",
        "//jax:pallas_tpu",
    ] + py_deps("absl/testing") + py_deps("hypothesis") + py_deps("numpy"),
)

jax_test(
    name = "pallas_vmap_test",
    srcs = [
        "pallas_vmap_test.py",
    ],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_a100",
        "gpu_h100",
        "gpu_p100",
        "gpu_p100_x32",
    ],
    enable_configs = [
        "gpu_a100_x32",
        "gpu_h100_x32",
    ],
    shard_count = 4,
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",
        "//jax:pallas_gpu_ops",
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy"),
)

jax_test(
    name = "mosaic_gpu_test",
    srcs = [
        "mosaic_gpu_test.py",
    ],
    config_tags_overrides = {
        "gpu_h100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_backends = [
        "cpu",
        "tpu",
    ],
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_a100",
        "gpu_a100_x32",
        "gpu_p100",
        "gpu_p100_x32",
        "gpu_h100",
    ],
    enable_configs = [
        "gpu_h100_x32",
    ],
    env = {
        "JAX_PALLAS_USE_MOSAIC_GPU": "1",
    },
    tags = ["notap"],
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",  # build_cleaner: keep
        "//jax/_src/pallas/mosaic_gpu",
    ] + py_deps("absl/testing") + py_deps("numpy"),
)

jax_test(
    name = "export_back_compat_pallas_test",
    srcs = ["export_back_compat_pallas_test.py"],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_a100",
        "gpu_h100",
        "gpu_p100",
        "gpu_p100_x32",
        "gpu_pjrt_c_api",
    ],
    enable_configs = [
        "gpu_a100_x32",
        "gpu_h100_x32",
    ],
    tags = [],
    deps = [
        "//jax:internal_export_back_compat_test_data",
        "//jax:internal_export_back_compat_test_util",
        "//jax:pallas",
        "//jax:pallas_gpu",  # build_cleaner: keep
        "//jax:pallas_tpu_ops",  # build_cleaner: keep
    ],
)

jax_test(
    name = "export_pallas_test",
    srcs = ["export_pallas_test.py"],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_a100",
        "gpu_h100",
        "gpu_p100",
        "gpu_p100_x32",
        "gpu_pjrt_c_api",
    ],
    enable_configs = [
        "gpu_a100_x32",
    ],
    tags = [],
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",  # build_cleaner: keep
        "//jax:pallas_tpu",  # build_cleaner: keep
    ],
)

jax_test(
    name = "pallas_shape_poly_test",
    srcs = ["pallas_shape_poly_test.py"],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_configs = [
        "gpu_x32",
        "gpu_h100",
        "gpu_p100",
        "gpu_p100_x32",
        "gpu_pjrt_c_api",
    ],
    enable_configs = [
        "gpu_a100_x32",
    ],
    tags = [],
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",  # build_cleaner: keep
        "//jax:pallas_tpu",  # build_cleaner: keep
        "//jax/experimental/export",
    ],
)

jax_test(
    name = "pallas_error_handling_test",
    srcs = [
        "pallas_error_handling_test.py",
    ],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    deps = [
        "//jax:pallas",
        "//jax:pallas_tpu",
        "//jax/_src/pallas/mosaic:random",
        "//third_party/py/absl/testing:absltest",
        "//third_party/py/absl/testing:parameterized",
    ] + py_deps("numpy"),
)

jax_test(
    name = "tpu_all_gather_test",
    srcs = [
        "tpu_all_gather_test.py",
    ],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    deps = [
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy") + py_deps("hypothesis"),
)

jax_test(
    name = "tpu_gmm_test",
    srcs = [
        "tpu_gmm_test.py",
    ],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    shard_count = 50,
    tags = [
        "noasan",  # Times out.
        "nomsan",  # Times out.
        "notsan",  # Times out.
    ],
    deps = [
        "//jax:pallas_tpu_ops",
    ] + py_deps([
        "absl/testing",
        "absl/flags",
        "numpy",
        "hypothesis",
    ]),
)

jax_test(
    name = "tpu_pallas_test",
    srcs = ["tpu_pallas_test.py"],
    # The flag is necessary for ``pl.debug_print`` tests to work on TPU.
    args = ["--logtostderr"],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    deps = [
        "//jax:extend",
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ],
)

jax_test(
    name = "tpu_ops_test",
    srcs = [
        "tpu_ops_test.py",
    ],
    disable_backends = [
        "gpu",
    ],
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",  # build_cleaner: keep
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("hypothesis") + py_deps("numpy"),
)

jax_test(
    name = "tpu_pallas_distributed_test",
    srcs = ["tpu_pallas_distributed_test.py"],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    deps = [
        "//jax:extend",
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ],
)

jax_test(
    name = "tpu_pallas_pipeline_test",
    srcs = ["tpu_pallas_pipeline_test.py"],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    shard_count = 5,
    tags = [
        "noasan",  # Times out.
        "nomsan",  # Times out.
        "notsan",  # Times out.
    ],
    deps = [
        "//jax:extend",
        "//jax:pallas_tpu",
        "//jax:pallas_tpu_ops",
    ] + py_deps("hypothesis"),
)

jax_test(
    name = "tpu_pallas_async_test",
    srcs = ["tpu_pallas_async_test.py"],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    tags = [
    ],
    deps = [
        "//jax:pallas_tpu",
    ],
)

jax_test(
    name = "tpu_pallas_mesh_test",
    srcs = ["tpu_pallas_mesh_test.py"],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    tags = [
        "noasan",
        "nomsan",
        "notsan",
    ],
    deps = [
        "//jax:extend",
        "//jax:pallas_tpu",
    ],
)

jax_test(
    name = "tpu_pallas_random_test",
    srcs = [
        "tpu_pallas_random_test.py",
    ],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    deps = [
        "//jax:pallas",
        "//jax:pallas_tpu",
        "//jax/_src/pallas/mosaic:random",
        "//third_party/py/absl/testing:absltest",
        "//third_party/py/absl/testing:parameterized",
    ] + py_deps("numpy"),
)

jax_test(
    name = "tpu_paged_attention_kernel_test",
    srcs = ["tpu_paged_attention_kernel_test.py"],
    disable_backends = [
        "cpu",
        "gpu",
    ],
    shard_count = 5,
    tags = [
        "noasan",  # Times out.
        "nomsan",  # Times out.
        "notsan",  # Times out.
    ],
    deps = [
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy"),
)

jax_test(
    name = "tpu_splash_attention_kernel_test",
    srcs = [
        "tpu_splash_attention_kernel_test.py",
    ],
    disable_backends = [
        "gpu",
        "cpu",
    ],
    shard_count = 24,
    tags = [
        "noasan",  # Times out.
        "nomsan",  # Times out.
        "notsan",  # Times out.
    ],
    deps = [
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy") + py_deps("hypothesis"),
)

jax_test(
    name = "tpu_splash_attention_mask_test",
    srcs = [
        "tpu_splash_attention_mask_test.py",
    ],
    disable_backends = [
        "gpu",
    ],
    deps = [
        "//jax:pallas_tpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy") + py_deps("hypothesis"),
)

jax_test(
    name = "gpu_attention_test",
    srcs = [
        "gpu_attention_test.py",
    ],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_backends = [
        "tpu",
    ],
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_p100",
        "gpu_p100_x32",
        "gpu_a100",
        "gpu_h100",
    ],
    enable_configs = [
        "gpu_a100_x32",
        "gpu_h100_x32",
    ],
    shard_count = 1,
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",  # build_cleaner: keep
        "//jax:pallas_gpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy"),
)

jax_test(
    name = "gpu_ops_test",
    srcs = [
        "gpu_ops_test.py",
    ],
    config_tags_overrides = {
        "gpu_a100_x32": {
            "ondemand": False,  # Include in presubmit.
        },
    },
    disable_backends = [
        "tpu",
    ],
    disable_configs = [
        "gpu",
        "gpu_x32",
        "gpu_a100",
        "gpu_h100",
        "gpu_p100",
        "gpu_p100_x32",
    ],
    enable_configs = [
        "gpu_a100_x32",
        "gpu_h100_x32",
    ],
    shard_count = 2,
    deps = [
        "//jax:pallas",
        "//jax:pallas_gpu",
        "//jax:pallas_gpu_ops",
    ] + py_deps("absl/testing") + py_deps("numpy"),
)
