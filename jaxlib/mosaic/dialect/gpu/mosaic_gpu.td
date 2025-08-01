/* Copyright 2024 The JAX Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#ifndef THIRD_PARTY_PY_JAX_JAXLIB_MOSAIC_DIALECT_GPU_MOSAIC_GPU_TD_
#define THIRD_PARTY_PY_JAX_JAXLIB_MOSAIC_DIALECT_GPU_MOSAIC_GPU_TD_

include "mlir/Dialect/LLVMIR/LLVMOpBase.td"
include "mlir/Dialect/LLVMIR/BasicPtxBuilderInterface.td"
include "mlir/Interfaces/ControlFlowInterfaces.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/BuiltinAttributeInterfaces.td"
include "mlir/IR/BuiltinTypeInterfaces.td"
include "mlir/IR/CommonAttrConstraints.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/IR/DialectBase.td"
include "mlir/IR/EnumAttr.td"
include "mlir/IR/OpBase.td"

def MosaicGPU_Dialect : Dialect {
  let name = "mosaic_gpu";
  let cppNamespace = "::mosaic_gpu";
  let useDefaultTypePrinterParser = 1;
  let useDefaultAttributePrinterParser = 1;
}

class MosaicGPU_Type<string name, string mnemonic_, list<Trait> traits = []>
    : TypeDef<MosaicGPU_Dialect, name, traits> {
  let mnemonic = mnemonic_;
}

class MosaicGPU_Attr<string name, string mnemonic_, list<Trait> traits = []>
    : AttrDef<MosaicGPU_Dialect, name, traits> {
  let mnemonic = mnemonic_;
}

def MosaicGPU_Barrier : MosaicGPU_Type<"Barrier", "barrier", [MemRefElementTypeInterface]> {
  let summary = "barrier";
  let description = "A barrier to use for synchronizing threads";
}

def LLVM_PointerShared : LLVM_PointerInAddressSpace<3>;

def MosaicGPU_InitializeBarrierOp : Op<MosaicGPU_Dialect, "initialize_barrier",
                                      []> {
  let summary = "Initializes a memref of barriers";
  let description = [{
    Initializes a memref of barriers each meant to synchronize exactly
    `arrival_count` threads.

    The base pointer of the result memref corresponds to `base_pointer`, which
    must be a pointer to a shared memory location.
  }];

  let arguments = (ins
    LLVM_PointerShared:$base_pointer,
    ConfinedAttr<I64Attr, [IntPositive]>:$arrival_count);
  let results = (outs MemRefOf<[MosaicGPU_Barrier]>:$barriers_ref);

  let assemblyFormat = [{
    $base_pointer $arrival_count attr-dict `:` type($barriers_ref)
  }];
}

def MosaicGPU_ArriveExpectTxOp : Op<MosaicGPU_Dialect, "arrive_expect_tx", []> {
  let summary = "Executes an arrive.expect_tx operation on the given barrier.";

  let arguments = (ins
    MemRefRankOf<[MosaicGPU_Barrier], [0]>:$barrier,
    ConfinedAttr<I32Attr, [IntNonNegative]>:$expect_tx);

  let assemblyFormat = [{
    `barrier` `(` $barrier `:` type($barrier) `)`
    $expect_tx
    attr-dict
  }];
}

def MosaicGPU_WaitOp : Op<MosaicGPU_Dialect, "wait", []> {
  let summary = "Executes a wait operation on the given barrier.";
  let description = [{
    All threads in the warpgroup will block, waiting on the provided barrier
    until:
      - all pending threads have arrived on the barrier
      - all expected byte transfers have been completed
      - the barrier's parity matches the provided parity
  }];

  let arguments = (ins
    MemRefRankOf<[MosaicGPU_Barrier], [0]>:$barrier,
    I1:$parity
  );
  let assemblyFormat = [{
    `barrier` `(` $barrier `:` type($barrier) `)`
    `parity` `(` $parity `:` type($parity) `)`
    attr-dict
  }];
}

def MosaicGPU_WGStridedFragLayout : AttrDef<MosaicGPU_Dialect, "WGStridedFragLayout", []> {
  let summary = "Annotates an array that can be collapsed to 1D and sharded across threads.";
  let description = [{
    This layout is typically used when working with pointwise operations, or
    other operations with trivial data dependency patterns.

    The layout holds the shape of the nD array it is meant to annotate, and a
    vector size representing the number of contiguous elements sharded to each
    thread.
  }];

  let parameters = (ins "::mlir::ArrayAttr":$shape, "int":$vector_size);
  let mnemonic = "WGStridedFragLayout";
  let assemblyFormat = "`<` $shape`,` $vector_size `>`";
}

def MosaicGPU_WGSplatFragLayout : AttrDef<MosaicGPU_Dialect, "WGSplatFragLayout", []> {
  let summary = "Annotates an array that is the result of a splat.";
  let description = [{
    This layout is used to handle splat values. In this case, each thread in
    the warpgroup gets a single copy of the value.

    The layout holds the shape that the initial scalar is splatted to.
  }];

  let parameters = (ins "::mlir::ArrayAttr":$shape);
  let mnemonic = "WGSplatFragLayout";
  let assemblyFormat = "`<` $shape `>`";
}

def MosaicGPU_Replicated : AttrDef<MosaicGPU_Dialect, "Replicated", []> {
  let summary = "Indicates a replicated dimension in a tiled layout.";
  let description = [{
    See mosaic/gpu/fragmented_array.py -> Replicated for more details.
  }];

  let parameters = (ins "int":$times);
  let mnemonic = "Replicated";
  let assemblyFormat = "`<` `times` `=` $times `>`";
}

def MosaicGPU_TiledLayout : AttrDef<MosaicGPU_Dialect, "TiledLayout", []> {
  let summary = "A layout derived from a tiling expression.";
  let description = [{
    See mosaic/gpu/fragmented_array.py -> TiledLayout for more details.
  }];

  let parameters = (ins
    "::mlir::ArrayAttr":$tiling,
    "::mlir::ArrayAttr":$warp_dims,
    "::mlir::ArrayAttr":$lane_dims,
    "int":$vector_dim
  );
  let mnemonic = "TiledLayout";
  let assemblyFormat = "`<` $tiling `,` `warp_dims` `=` $warp_dims `,` "
      "`lane_dims` `=` $lane_dims `,` `vector_dim` `=` $vector_dim `>`";
}


// Note: This duplicates the Dimension enum in mlir/Dialect/GPU/IR/GPUOps.td
// but it was not possible to reuse that definition. Including that file
// pulls in ops definitions that we don't want and they fail to compile.
def MosaicGPU_Dimension : I32EnumAttr<"Dimension",
    "a dimension, either 'x', 'y', or 'z'",
    [
      I32EnumAttrCase<"x", 0>,
      I32EnumAttrCase<"y", 1>,
      I32EnumAttrCase<"z", 2>
    ]>{
  let cppNamespace = "::mosaic_gpu";
}

def MosaicGPU_SwizzlingMode : I32EnumAttr<"SwizzlingMode",
    "What swizzling to use for a memory access.",
    [
      I32EnumAttrCase<"kNoSwizzle", 16>,
      I32EnumAttrCase<"k32ByteSwizzle", 32>,
      I32EnumAttrCase<"k64ByteSwizzle", 64>,
      I32EnumAttrCase<"k128ByteSwizzle", 128>
    ]>{
  let cppNamespace = "::mosaic_gpu";
}

def TileTransformAttr : MosaicGPU_Attr<"TileTransform", "tile"> {
  let parameters = (ins ArrayRefParameter<"int32_t", "tiling">:$tiling);
  let summary = "Specifies a transform that tiles suffix dimensions of a memref in SMEM.";
  let description = [{
    For example, given a memref of shape (5, 128, 128) and a tiling of (64, 32),
    the shape of the result will be (5, 2, 4, 64, 32). The shape always ends
    with the tile shape, and the size of tiled dimensions is divided by the tile
    size. This is especially useful for swizzled WGMMA, which expect tiled
    layouts in shared memory.

    Each tiled dimension must have a size that is either smaller than the
    corresponding tile size or a multiple of the tile size.
  }];
  let assemblyFormat = "`<` $tiling `>`";
}

def TransposeTransformAttr : MosaicGPU_Attr<"TransposeTransform", "transpose"> {
  let parameters = (ins ArrayRefParameter<"int32_t", "permutation">:$permutation);
  let summary = "Specifies a transpose transform of a memref in SMEM.";
  let assemblyFormat = "`<` $permutation `>`";
}

def SwizzleTransformAttr : MosaicGPU_Attr<"SwizzleTransform", "swizzle"> {
  let parameters = (ins "SwizzlingModeAttr":$swizzle);

  let summary = "Specifies a swizzle transform of a memref in SMEM.";
  let assemblyFormat = "`<` $swizzle `>`";
}

def MosaicGPU_AsyncLoadOp : Op<MosaicGPU_Dialect, "async_load",
      [AttrSizedOperandSegments]> {
  let summary = "Schedules an async load of a MemRef from GMEM to SMEM";
  let description = [{
    Schedules an async copy of the contents of the `source` MemRef in GMEM to
    the `destination` MemRef in SMEM. The `destination` MemRef in SMEM must be
    contiguous.

    Upon completion of the copy, the `complete-tx(complete-count)` operation
    will always be executed on the provided `barrier`.

    The `indices` and `slice_lengths` inputs define what slice of the GMEM
    `source` corresponds to the SMEM `destination`. Both `indices` and
    `slice_lengths` must have a length equal to the rank of the `source`. The
    values in `indices` are the starting indices of each dimension and the
    values in `slice_lengths` are the lengths. Providing -1 in `slice_lengths`
    indicates that the slice length is 1 and that the corresponding dimension
    should be collapsed and does not appear in the `destination` MemRef.

    The data is written in row-major order to the contiguous SMEM `destination`.
    The `source` data does not need to be contiguous, except for the last
    (and minor-most) dimension.

    The `collective` attribute can be provided to use TMA multicast to more
    efficiently load the GMEM data in cases where multiple thread blocks are
    grouped together in a cluster and need to load the same data. Each block in
    a cluster will first load a slice from GMEM to SMEM and then the slices will
    be multicast to all other blocks in the cluster. In this way TMA multicast
    guarantees L2 cache hits. The `collective` attribute is the list of
    cluster dimensions along which to partition the input data loads.

    The `predicate` allows scheduling the transfer conditionally. The async copy
   is always scheduled by at most a single lane in the warpgroup.
  }];

  let arguments = (ins
    AnyMemRef:$source,
    AnyMemRef:$destination,
    MemRefRankOf<[MosaicGPU_Barrier], [0]>:$barrier,
    Variadic<I32>:$indices,
    PtxPredicate:$predicate,

    // Attributes
    DenseI64ArrayAttr:$slice_lengths,
    TypedArrayAttrBase<MosaicGPU_Dimension, "dimensions">:$collective
  );

  let assemblyFormat = [{
    `source` `(` $source `:` type($source) `)`
    `destination` `(` $destination `:` type($destination) `)`
    `barrier` `(` $barrier `:` type($barrier) `)`
    `indices` `(` $indices `)`
    `predicate` `(` $predicate `)`
    attr-dict
  }];

  let hasVerifier = 1;
}

def MosaicGPU_AsyncStoreOp : Op<MosaicGPU_Dialect, "async_store",
      [AttrSizedOperandSegments]> {
  let summary = "Schedules an async store of a MemRef from SMEM to GMEM";
  let description = [{
    Schedules an async store of the contents of the `source` MemRef in SMEM to
    the `destination` MemRef in GMEM. The `source` MemRef in SMEM must be
    contiguous.

    The `indices` and `slice_lengths` inputs define what slice of the GMEM
    `destination` corresponds to the SMEM `source`. Both `indices` and
    `slice_lengths` must have a length equal to the rank of the `destination`.
    The values in `indices` are the starting indices of each dimension and the
    values in `slice_lengths` are the lengths. Providing -1 in `slice_lengths`
    indicates that this dimension is collapsed in the `source` and needs to be
    expanded to a slice of size 1 in the `destination`.

    The data is written in row-major order to the GMEM `destination`. The
    `source` data in SMEM needs to be contiguous, but the `destination` GMEM
    does not.

    The `predicate` allows scheduling the transfer conditionally. The async copy
    is always scheduled by at most a single lane in the warpgroup.
  }];

  let arguments = (ins
    AnyMemRef:$source,
    AnyMemRef:$destination,
    Variadic<I32>:$indices,
    PtxPredicate:$predicate,

    // Attributes
    DenseI64ArrayAttr:$slice_lengths,
    DefaultValuedOptionalAttr<BoolAttr, "true">:$commit_group
  );

  let assemblyFormat = [{
    `source` `(` $source `:` type($source) `)`
    `destination` `(` $destination `:` type($destination) `)`
    `indices` `(` $indices `)`
    `predicate` `(` $predicate `)`
    attr-dict
  }];

  let hasVerifier = 1;
}

def MosaicGPU_WGMMASupportedType : AnyTypeOf<[F16, BF16, F32],
    "A type supported by the WGMMA operation">;

def MosaicGPU_LayoutCastOp : Op<MosaicGPU_Dialect, "layout_cast",
    [InferTypeOpInterface]> {
  let summary = "Casts a vector to a new layout.";
  let description = [{Casts a vector value to a new strided or tiled layout.}];
  let arguments = (ins
    AnyVectorOfAnyRank:$x,

    // Attributes
    AnyAttrOf<[
      MosaicGPU_WGStridedFragLayout,
      MosaicGPU_TiledLayout
    ]>:$new_layout
  );

  let results = (outs AnyVectorOfAnyRank);

  let assemblyFormat = "`x` `(` $x `:` type($x) `)` attr-dict";

  let extraClassDeclaration = [{
    static llvm::LogicalResult inferReturnTypes(
        mlir::MLIRContext *,
        std::optional<mlir::Location> location,
        mlir::ValueRange operands,
        mlir::DictionaryAttr attributes,
        mlir::OpaqueProperties properties,
        mlir::RegionRange regions,
        llvm::SmallVectorImpl<mlir::Type> &inferredReturnTypes) {
      if (operands.empty()) {
        return ::mlir::emitOptionalError(
          location, "expected non-empty operands");
      }
      inferredReturnTypes.assign({operands[0].getType()});
      return ::mlir::success();
    }
  }];
}


def MosaicGPU_BroadcastInDimOp : Op<MosaicGPU_Dialect, "broadcast_in_dim", []> {
  let summary = "Broadcasts a vector to a new shape.";
  let description = [{
    `broadcast_dimensions` must have the same size as the rank of the input
    vector and for each input dimension, specifies which output dimension it
    corresponds to.
  }];

  let arguments = (ins
    AnyVectorOfAnyRank:$operand,

    // Attributes
    DenseI64ArrayAttr:$broadcast_dimensions
  );

  let results = (outs AnyVectorOfAnyRank);
  let assemblyFormat = [{
    `(` $operand `:` type($operand) `)` attr-dict `->` type(results)
  }];
  let hasVerifier = 1;
}


def MosaicGPU_SliceSMEMOp : Op<MosaicGPU_Dialect, "slice_smem", []> {
  let summary = "Constructs an SMEM MemRef with the requested type that begins at the specified SMEM offset address.";

  let arguments = (ins I32:$offset);
  let results = (outs AnyMemRef);
}

def MosaicGPU_WGMMAOp : Op<MosaicGPU_Dialect, "wgmma", [InferTypeOpInterface]> {
  let summary = "Multiply two matrices asynchronously using warpgroup level matrix multiply operations.";
  let description = [{
    Schedules WGMMA operations that perform the following matrix multiply and
    accumulate:

      accumulator = a * b + accumulator

    This operation supports larger inputs than the PTX-level WGMMA operation
    and will schedule as many PTX-level WGMMA operations as needed to
    accomplish the calculation. The `b` matrix, and optionally `a`, need to be
    provided as a 2-dimensional memref.

    The inputs should have the following shapes:
      - a: [groups_m * 64, groups_k * s]
      - b: [groups_k * s, groups_n * s]
      - accumulator: [groups_m * 64, groups_n * s]
    where `s == swizzle / element_bytewidth`.

    The output has an identical shape and type as the input accumulator.

    The `accumulator` is always in registers and `b` is always in shared memory.
    `a` and `b` must have the same element type and when `a` is in
    registers only F16 or BF16 are supported.

    The `accumulator` must be a vector with a FragmentedLayout. The WGMMA
    operation will be executed in the async proxy and any inputs in
    registers need to be synchronized with a memory fence.

    Usually `a` is read from shared memory if it is used directly in the WGMMA
    operation. If `a` needs to be transformed before it is used in the WGMMA
    operation, it may be more convenient to read it directly form registers.
    This avoids the need to store the data and wait for a fence.
  }];

  let arguments = (ins
    VectorOfRankAndType<[2], [MosaicGPU_WGMMASupportedType]>:$accumulator,
    AnyTypeOf<[
      MemRefRankOf<[MosaicGPU_WGMMASupportedType], [2]>,
      VectorOfRankAndType<[2], [MosaicGPU_WGMMASupportedType]>]>:$a,
    MemRefRankOf<[MosaicGPU_WGMMASupportedType], [2]>:$b
  );
  let results = (outs VectorOfRankAndType<[2], [MosaicGPU_WGMMASupportedType]>);

  let assemblyFormat = [{
    `accumulator` `(` $accumulator `:` type($accumulator) `)`
    `a` `(` $a `:` type($a) `)`
    `b` `(` $b `:` type($b) `)`
    attr-dict
    `->` type(results)
  }];

  let extraClassDeclaration = [{
    static llvm::LogicalResult inferReturnTypes(
        mlir::MLIRContext *,
        std::optional<mlir::Location> location,
        mlir::ValueRange operands,
        mlir::DictionaryAttr attributes,
        mlir::OpaqueProperties properties,
        mlir::RegionRange regions,
        llvm::SmallVectorImpl<mlir::Type> &inferredReturnTypes) {
      if (operands.empty()) {
        return ::mlir::emitOptionalError(
          location, "expected non-empty operands");
      }
      inferredReturnTypes.assign({operands[0].getType()});
      return ::mlir::success();
    }
  }];

  let hasVerifier = 1;
}

def MosaicGPU_TmemAttr : MosaicGPU_Attr<"Tmem", "tmem"> {
  let summary = "Tensor memory space.";
}

def MosaicGPU_TcGen05MMASupportedABType : AnyTypeOf<[F16, F32, BF16, TF32, F8E4M3FN, F8E5M2, F6E2M3FN, F6E3M2FN, F4E2M1FN, I8],
    "A type supported by the `a` and `b` operands of the `tcgen05.mma` instruction">;

def MosaicGPU_TcGen05MMAOp : Op<MosaicGPU_Dialect, "tcgen05_mma", [InferTypeOpInterface, AttrSizedOperandSegments]> {
  let summary = "Perform a matrix multiply-accumulate operation using the `tcgen05.mma` instruction.";
  let description = [{
    Schedules `tcgen05.mma` instructions that perform the following matrix
    multiply and accumulate:

      accumulator = a * b + accumulator

    This operation supports larger inputs than the PTX-level MMA instruction
    and will schedule as many PTX-level MMA instructions as needed to
    accomplish the calculation.

    The inputs should have the following shapes:
      - a: [groups_m * m, groups_k * s]
      - b: [groups_k * s, groups_n * s]
      - accumulator: [groups_m * m, groups_n * s]
    where `s == swizzle / element_bytewidth` and `m` is specified according to
    https://docs.nvidia.com/cuda/parallel-thread-execution/#tcgen05-matrix-shape.

    The output has an identical shape and type as the input accumulator.

    The `accumulator`, `a` and `b` matrices need to be provided as 2-dimensional
    memrefs. The `accumulator` is always in TMEM and `b` is always in SMEM.
    `a` can be in TMEM or SMEM. `a` and `b` must have the same element
    type and when `a` is in TMEM only F16 or BF16 are supported.

    `a_scale` and `b_scale` are optional scaling matrices that reside in TMEM.
    When set the operation is defined as:

      accumulator = (a * a_scale) * (b * b_scale) + accumulator

    `accumulate` is a boolean that indicates whether to perform the accumulate
    step.
  }];

  let arguments = (ins
    MemRefRankOf<[F16, F32, I32], [2]>:$accumulator,
    MemRefRankOf<[MosaicGPU_TcGen05MMASupportedABType], [2]>:$a,
    MemRefRankOf<[MosaicGPU_TcGen05MMASupportedABType], [2]>:$b,
    I1:$accumulate,
    // TODO: allanrenucci - F8E4M3FNU (ue4m3) does not exist in MLIR. We use F8E4M3FN (e4m3) instead.
    Optional<MemRefRankOf<[F8E8M0FNU, F8E4M3FN], [2]>>:$a_scaled,
    Optional<MemRefRankOf<[F8E8M0FNU, F8E4M3FN], [2]>>:$b_scaled,
    DefaultValuedAttr<BoolAttr, "false">:$collective
  );
  let results = (outs MemRefRankOf<[F16, F32, I32], [2]>);

  let extraClassDeclaration = [{
    static llvm::LogicalResult inferReturnTypes(
        mlir::MLIRContext *,
        std::optional<mlir::Location> location,
        mlir::ValueRange operands,
        mlir::DictionaryAttr attributes,
        mlir::OpaqueProperties properties,
        mlir::RegionRange regions,
        llvm::SmallVectorImpl<mlir::Type> &inferredReturnTypes) {
      if (operands.empty()) {
        return ::mlir::emitOptionalError(
          location, "expected non-empty operands");
      }
      inferredReturnTypes.assign({operands[0].getType()});
      return ::mlir::success();
    }
  }];

  let hasVerifier = 1;
}

def MosaicGPU_OptimizationBarrierOp : Op<MosaicGPU_Dialect, "optimization_barrier",
    [InferTypeOpInterface]> {
  let summary = "Prevents MLIR from moving operations across the barrier.";

  let arguments = (ins
    Variadic<AnyType>:$operands
  );
  let results = (outs Variadic<AnyType>);

  let extraClassDeclaration = [{
    static llvm::LogicalResult inferReturnTypes(
        mlir::MLIRContext *,
        std::optional<mlir::Location> location,
        mlir::ValueRange operands,
        mlir::DictionaryAttr attributes,
        mlir::OpaqueProperties properties,
        mlir::RegionRange regions,
        llvm::SmallVectorImpl<mlir::Type> &inferredReturnTypes) {
      if (operands.empty()) {
        return ::mlir::emitOptionalError(
          location, "expected non-empty operands");
      }
      ::mlir::TypeRange operand_types = operands.getTypes();
      inferredReturnTypes.assign(operand_types.begin(), operand_types.end());
      return ::mlir::success();
    }
  }];
}

def MosaicGPU_ReturnOp : Op<MosaicGPU_Dialect, "return",
    [Pure, ReturnLike, Terminator, HasParent<"CustomPrimitiveOp">]>
{
  let summary = "Terminator for the region in a `CustomPrimitiveOp`";
  let description = [{
    The `return` op is a terminator that indicates the end of execution
    within a `CustomPrimitiveOp`'s region. It can optionally return some values,
    which become the results of the parent `CustomPrimitiveOp`.

    The declared results of the parent `CustomPrimitiveOp` must match the
    operand types of this op.
  }];

  // The operand's type must match the parent CustomPrimitiveOp's result type.
  let arguments = (ins Variadic<AnyVectorOfAnyRank>:$operands);
  let assemblyFormat = [{ attr-dict ($operands^ `:` type($operands))? }];
  let hasVerifier = 1;
}

def MosaicGPU_CustomPrimitiveOp : Op<MosaicGPU_Dialect, "custom_primitive",
    [IsolatedFromAbove, SingleBlockImplicitTerminator<"ReturnOp">]>
{
  let summary = "Allows defining a custom Mosaic GPU primitive.";
  let description = [{
    Allows defining a custom Mosaic GPU primitive.

    Custom primitives should carry input and output layouts for each of their
    vector operands and outputs, and input transforms for each of their memref
    operands that live in SMEM.

    Custom primitives can only return vectors.
  }];

  let arguments = (
    ins Variadic<AnyType>:$operands,
    // Attributes
    ArrayAttr:$in_layouts,
    ArrayAttr:$in_transforms,
    ArrayAttr:$out_layouts
  );

  let results = (outs Variadic<AnyVectorOfAnyRank>);
  let regions = (region AnyRegion:$body);

  let hasVerifier = 1;
}

def MosaicGPU_WithTransformsOp : Op<MosaicGPU_Dialect, "with_transforms",
    [SameOperandsAndResultType]> {
  let summary = "A noop that allows manually setting transforms on a memref.";
  let description = [{
    This op enforces the provided transforms on the parameter memref.
  }];

  let arguments = (
    ins AnyMemRef:$ref,
    // Attributes
    ArrayAttr:$transforms
  );

  let results = (outs AnyMemRef);
}

def MosaicGPU_TmemAllocOp : Op<MosaicGPU_Dialect, "tmem_alloc", []> {
  let summary = "Allocates a chunk of TMEM.";
  let description = [{
    This op allocates a chunk of TMEM and stores the pointer to the memory
    in the provided SMEM memref.

    The `smem_ptr` is a pointer in SMEM where a pointer to the allocated
    TMEM will be stored. The op returns a memref to the allocated TMEM. The
    result must have a shape with dimensions [rows, logical_columns]. If
    `packing` is 1, then the number of logical (unpacked) columns is equal to
    the number of allocated columns in TMEM. Otherwise, these equations
    must hold:

        packing = 32 / bitwidth(element type of result)
        unpacked_columns = allocated_columns * packing

    The number of allocated columns in TMEM can be any power of two in the
    range [32, 512]. If `exact` is `true`, then the calculated
    number of allocated columns must match that restriction. If `exact` is
    `false` and the calculated number of allocated columns is less than 32 or
    not a power of two, then it will be rounded up to the nearest power of two
    larger or equal to 32.

    If `collective` is `true` 2 CTAs will perform the allocation collectively,
    otherwise, only one CTA will perform the allocation.
  }];

  let arguments = (ins
    MemRefRankOf<[I32], [0]>:$smem_ptr,

    // Attributes
    DefaultValuedAttr<BoolAttr, "false">:$collective,
    DefaultValuedAttr<BoolAttr, "true">:$exact,
    DefaultValuedAttr<ConfinedAttr<I32Attr, [IntPositive]>, "1">:$packing
  );

  let results = (outs MemRefRankOf<[AnyType], [2]>);

  let assemblyFormat = [{
    `smem_ptr` `(` $smem_ptr `:` type($smem_ptr) `)`
    attr-dict `->` type(results)
  }];

  let hasVerifier = 1;
}

def MosaicGPU_TmemDeallocOp : Op<MosaicGPU_Dialect, "tmem_dealloc", []> {
  let summary = "Deallocates a chunk of TMEM.";

  let arguments = (ins MemRefRankOf<[AnyType], [2]>:$tmem_ref);

  let assemblyFormat = [{
    `tmem_ref` `(` $tmem_ref `:` type($tmem_ref) `)`
    attr-dict
  }];

  let hasVerifier = 1;
}

#endif // THIRD_PARTY_PY_JAX_JAXLIB_MOSAIC_DIALECT_GPU_MOSAIC_GPU_TD_
