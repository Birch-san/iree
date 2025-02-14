// Copyright 2021 The IREE Authors
//
// Licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#ifndef IREE_DIALECT_LINALGEXT_OPS
#define IREE_DIALECT_LINALGEXT_OPS

include "iree-dialects/Dialect/LinalgExt/IR/LinalgExtBase.td"
include "iree-dialects/Dialect/LinalgExt/IR/LinalgExtInterfaces.td"
include "iree-dialects/Dialect/LinalgExt/IR/TiledOpInterface.td"
include "mlir/Interfaces/ControlFlowInterfaces.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/Interfaces/TilingInterface.td"
include "mlir/Interfaces/ViewLikeInterface.td"


//===----------------------------------------------------------------------===//
// Base class.
//===----------------------------------------------------------------------===//

class IREELinalgExt_PureOp<string mnemonic, list<Trait> traits = []> :
    Op<IREELinalgExt_Dialect, mnemonic, traits> {
}

class IREELinalgExt_Op<string mnemonic, list<Trait> traits = []> :
    IREELinalgExt_PureOp<mnemonic, !listconcat(traits,
        [AttrSizedOperandSegments,
         DeclareOpInterfaceMethods<MemoryEffectsOpInterface>,
         LinalgExtInterface,
         SingleBlockImplicitTerminator<"::mlir::iree_compiler::IREE::LinalgExt::YieldOp">,
         ReifyRankedShapedTypeOpInterface
  ])> {
  let hasVerifier = 1;
  let hasCustomAssemblyFormat = 1;
  code extraLinalgExtOpClassDeclaration = [{
    SmallVector<Value> getDestinationOperands(OpBuilder &b) {
      SmallVector<Value> dest(outputs().begin(), outputs().end());
      return dest;
    }

    LogicalResult reifyResultShapes(OpBuilder &b,
        mlir::ReifiedRankedShapedTypeDims &reifiedReturnShapes) {
      return llvm::cast<LinalgExtOp>(getOperation()).reifyResultShapes(b,
          reifiedReturnShapes);
    }
  }];
}

//===----------------------------------------------------------------------===//
// Non-structured ops
//===----------------------------------------------------------------------===//

def IREELinalgExt_ScatterOp : IREELinalgExt_Op<"scatter",
    [DeclareOpInterfaceMethods<TiledOpInterface,
        ["getTiledImplementation", "generateScalarImplementation"]>]> {
  let summary = "Scatter operator";
  let description = [{
    Based on XLA operation semantics, takes two `inputs` (`update` and
    `indices`) and `outputs` value (`original`). The operation updates
    the value at the slices specified by `indices` by combining the
    current value with the value in `updates` using the computation
    specified in `region`. The `region` specifies a binary operation
    of signature (T, T) -> T, where `T` is the element-type of
    `updates` (and `original`). The first argument correspond the
    value to be updated (i.e. from `updates`), and the second the
    current value (i.e. value from `original`).

    The `indices` is a 2D tensor/memref type. The first dim is the number of
    updates, and the second dim is index depth. The index depth should always be
    static.

    The first dim of `updates` and `indices` is identical, since they represent
    the number of updates.

    The rank of the `original`/`result` is at least
    `index_depth + rank(%updates) - 1`. The first `index_depth` indices are
    derived from `indices` and the shape of update value has the last
    rank(%original) - index_depth values match %(originals) last dimensions,
    with the previous dims extending from the index offsets.

    The unique_indices attribute carries the information whether all the indices
    are unique. If there are repeated indices, the first iteration loop will be
    marked as reduction.

    The shapes definition follows tensorflow operations execept that it force
    batch dims to be 1D. See more information in
      https://www.tensorflow.org/api_docs/python/tf/tensor_scatter_nd_update
  }];
  let arguments = (ins
      Variadic<AnyRankedTensorOrMemRefType>:$inputs,
      Variadic<AnyRankedTensorOrMemRefType>:$outputs,
      DefaultValuedAttr<BoolAttr, "true">:$unique_indices
  );
  let results = (outs Variadic<AnyRankedTensor>:$results);
  let regions = (region AnyRegion:$region);
  let assemblyFormat = [{
    attr-dict `unique_indices` `(` $unique_indices `)`
    (`ins` `(` $inputs^ `:` type($inputs) `)`)?
    `outs` `(` $outputs `:` type($outputs) `)`
    $region (`->` type($results)^)?
  }];
  let extraClassDeclaration = extraLinalgExtOpClassDeclaration # [{

    int64_t getIndexDepth() {
      return getInputOperand(1)
          ->get()
          .getType()
          .cast<ShapedType>()
          .getShape()
          .back();
    }

    Value updates() {
      return getInputOperand(0)->get();
    }

    ShapedType getUpdateType() {
      return updates().getType().cast<ShapedType>();
    }

    Value indices() {
      return getInputOperand(1)->get();
    }

    ShapedType getIndicesType() {
      return indices().getType().cast<ShapedType>();
    }

    Value original() {
      return getOutputOperand(0)->get();
    }

    ShapedType getOriginalType() {
      return original().getType().cast<ShapedType>();
    }

    int64_t getUpdateSliceRank() {
      return updates().getType().cast<ShapedType>().getRank() - 1;
    }

    bool isScalarUpdate() {
      return getUpdateSliceRank() == 0;
    }
  }];
}

def IREELinalgExt_SortOp : IREELinalgExt_Op<"sort",
    [DeclareOpInterfaceMethods<TiledOpInterface,
        ["getPartitionableLoops", "generateScalarImplementation",
         "getTiledImplementation"]>]> {
  let summary = "Sort operator";
  let description = [{
    Based on XLA operation semantics, sorts the given `operands` at the given
    `dimension` with the given `comparator`.

    See https://www.tensorflow.org/xla/operation_semantics#sort.
  }];

  let arguments = (ins Variadic<AnyType>:$inputs,
                       Variadic<AnyShaped>:$outputs,
                       I64Attr:$dimension
  );
  let results = (outs Variadic<AnyRankedTensor>:$results);
  let regions = (region AnyRegion:$region);
  let assemblyFormat = [{
    attr-dict
    `dimension` `(` $dimension `)`
    (`ins` `(` $inputs^ `:` type($inputs) `)`)?
    `outs` `(` $outputs `:` type($outputs) `)`
    $region (`->` type($results)^)?
  }];
  let extraClassDeclaration = extraLinalgExtOpClassDeclaration # [{
    Value operand(int index) {
      return outputs()[index];
    }
    ShapedType getOperandType(int index) {
      return operand(index).getType().cast<ShapedType>();
    }
    int64_t getOperandRank() {
      return getOperandType(0).getRank();
    }
    ArrayRef<int64_t> getOperandShape() {
      return getOperandType(0).getShape();
    }
  }];
}

def IREELinalgExt_FftOp : IREELinalgExt_Op<"fft", [
  DeclareOpInterfaceMethods<TiledOpInterface,
                            [
                              "getPartitionableLoops", "getTiledImplementation",
                              "generateScalarImplementation"
                            ]>,
  DeclareOpInterfaceMethods<LinalgExtInterface>
]> {
  let summary = "Fft operator";
  let description = [{
    Apply 1D FFT to innermost dim. This is an iterative FFT, not recurrsive.
    Thus, the bit reversal is assumed applied on the input. The op carries an
    input -- stage, which indicates the level of reduction loop in the
    algorithm. It represents the computation body. For more details, see
    "Data reordering, bit reversal, and in-place algorithms" section in
    https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm

    The size of innermost dim is expected to be a power of 2.

    It is optional to carry coefficient tensors/buffers as inputs. In this
    context, they will be the second and third inputs.
  }];

  let arguments = (ins Variadic<AnyType>:$inputs,
                       Variadic<AnyShaped>:$outputs
  );
  let results = (outs Variadic<AnyRankedTensor>:$results);
  let assemblyFormat = [{
    attr-dict (`ins` `(` $inputs^ `:` type($inputs) `)`)?
    `outs` `(` $outputs `:` type($outputs) `)`
    (`:` type($results)^)?
  }];
  let extraClassDeclaration = extraLinalgExtOpClassDeclaration # [{
    Value getStage() { return inputs()[0]; }
    Value getReal() { return outputs()[0]; }
    Value getImag() { return outputs()[1]; }
    bool hasCoeff() { return getNumInputs() > 1; }
    void generateScalarImplWithoutCoeffBuf(
        OpBuilder & b, Location loc, ArrayRef<Value> operands, Value wholeSize);
    void generateScalarImplWithCoeffBuf(OpBuilder & b, Location loc,
                                        ArrayRef<Value> operands);
    Value getRealCoeff() {
      if (!hasCoeff()) return Value();
      return inputs()[1];
    }
    Value getImagCoeff() {
      if (!hasCoeff()) return Value();
      return inputs()[2];
    }
    ShapedType getOperandType() {
      return getReal().getType().cast<ShapedType>();
    }
    int64_t getOperandRank() {
      return getOperandType().getRank();
    }
    ArrayRef<int64_t> getOperandShape() {
      return getOperandType().getShape();
    }
    int64_t getFftLength() {
      return getOperandShape().back();
    }
  }];
}

def IREELinalgExt_ScanOp : IREELinalgExt_Op<"scan",
    [DeclareOpInterfaceMethods<TiledOpInterface,
      ["getPartitionableLoops", "generateScalarImplementation",
       "getTiledImplementation"]>]> {
  let summary = "Scan operator";
  let description = [{
    Computes the inclusive/exclusive scan along a given dimension.
  }];

  let arguments = (ins Variadic<AnyShaped>:$inputs,
                       Variadic<AnyShaped>:$outputs,
                       I64Attr:$dimension,
                       BoolAttr:$inclusive
  );

  let builders = [
    OpBuilder<(ins "ValueRange":$inputs, "ValueRange":$outputs,
      CArg<"int64_t", "0">:$dimension, CArg<"bool", "true">:$inclusive)>
  ];

  let results = (outs Variadic<AnyRankedTensor>:$results);
  let regions = (region AnyRegion:$region);
  let hasFolder = 1;
  let assemblyFormat = [{
    attr-dict
    `dimension` `(` $dimension `)`
    `inclusive` `(` $inclusive `)`
    `ins` `(` $inputs `:` type($inputs) `)`
    `outs` `(` $outputs `:` type($outputs) `)`
    $region (`->` type($results)^)?
  }];

  let extraClassDeclaration = extraLinalgExtOpClassDeclaration # [{
    Value input() {
      return getInputOperand(0)->get();
    }
    Value accumulator() {
      return getOutputOperand(1)->get();
    }
    Value output() {
      return getOutputOperand(0)->get();
    }
    ShapedType getOperandType() {
      return input().getType().cast<ShapedType>();
    }
    int64_t getOperandRank() {
      return getOperandType().getRank();
    }
  }];
}

def IREELinalgExt_ReverseOp : IREELinalgExt_Op<"reverse", [
  DeclareOpInterfaceMethods<
      TiledOpInterface,
      ["generateScalarImplementation", "getTiledImplementation"]>,
  DeclareOpInterfaceMethods<LinalgExtInterface>]> {
  let summary = "Reverse operator";
  let description = [{
    A temporary solution for lowering reverse ops into IREE, allowing IREE to
    tile and distribute them.
    }
  }];

  let arguments = (ins Variadic<AnyShaped>:$inputs,
                       Variadic<AnyShaped>:$outputs,
                       I64ElementsAttr:$dimensions
  );
  let results = (outs Variadic<AnyRankedTensor>:$results);
  let assemblyFormat = [{
    attr-dict `dimensions` `(` $dimensions `)`
    (`ins` `(` $inputs^ `:` type($inputs) `)`)?
    (`outs` `(` $outputs^ `:` type($outputs) `)`)?
    (`:` type($results)^)?
  }];
  let extraClassDeclaration = extraLinalgExtOpClassDeclaration # [{
    Value input() {
      return getInputOperand(0)->get();
    }
    Value output() {
      return getOutputOperand(0)->get();
    }
    ShapedType getOperandType() {
      return input().getType().cast<ShapedType>();
    }
    int64_t getOperandRank() {
      return getOperandType().getRank();
    }
    ArrayRef<int64_t> getOprerandShape() {
      return getOperandType().getShape();
    }
    SmallVector<int64_t> dims() {
      SmallVector<int64_t> ret;
      for (const APInt& elem : dimensions()) {
        ret.push_back(elem.getLimitedValue());
      }
      return ret;
    }
  }];
}

def IREELinalgExt_TopkOp : IREELinalgExt_Op<"topk",[
  DeclareOpInterfaceMethods<LinalgExtInterface>,
  DeclareOpInterfaceMethods<TiledOpInterface,
    ["generateScalarImplementation", "getPartitionableLoops", "getTiledImplementation"]>,
  SingleBlockImplicitTerminator<"::mlir::iree_compiler::IREE::LinalgExt::YieldOp">,
]>{
  let summary = "Top-K operator";
  let description = [{
   A Top-K operation for N-D tensors. Reduces the target dimension from the input
   size N down to K elements based on the supplied binary region.

   Accepts an N-D tensor input consisting of values and an optioanl N-D tensor
   for indices of those values (i32 type). If input indices aren't provided, the
   index mapping is inferred based on the k dim.  Both input values/indices
   tensors and output values/indicies tensors must have the same shape. Top-K is
   computed along the target dimension (from dimension()). Returns two output
   tensors of values and the indicies of Top-K results. The output dimensions
   must match the input save for the dimension that is reduced to K results.

   Region accepts lhs=[next N input] and rhs=[exiting K output] and yeilds an
   i1. If true, the two values are swapped:
     - For Top-K compoarision: >
     - For Min-K comparision: <
   Note: when the two values are equal, the first occurence is always selected.
  }];

  let arguments = (ins Variadic<AnyShaped>:$inputs,
                       Variadic<AnyShaped>:$outputs,
                       I64Attr:$dimension
  );

  let results = (outs Variadic<AnyRankedTensor>:$results);
  let regions = (region AnyRegion:$region);
  let assemblyFormat = [{
    attr-dict
    `dimension` `(` $dimension `)`
    `ins` `(` $inputs `:` type($inputs) `)`
    `outs` `(` $outputs `:` type($outputs) `)`
    $region (`->` type($results)^)?
  }];

  let extraClassDeclaration = extraLinalgExtOpClassDeclaration # [{
    Value values() {
      return getInputOperand(0)->get();
    }
    Optional<Value> indices() {
      if (getNumInputs() < 2) {
        return {};
      } else {
        return getInputOperand(1)->get();
      }
    }
    Value outputValues() {
      return getOutputOperand(0)->get();
    }
    Value outputIndices() {
      return getOutputOperand(1)->get();
    }
    ShapedType getInputType() {
      return values().getType().cast<ShapedType>();
    }
    int64_t getInputRank() {
      return getInputType().getRank();
    }
  }];
}
 
//===----------------------------------------------------------------------===//
// Pure ops
//===----------------------------------------------------------------------===//

def IREELinalgExt_YieldOp : IREELinalgExt_PureOp<"yield", [NoSideEffect, ReturnLike, Terminator]> {
  let summary = "LinalgExt yield op";
  let description = [{
    `iree_linalg_ext.yield` is a special terminator operation for blocks inside
    regions in `iree_linalg_ext` ops.
  }];

  let arguments = (ins Variadic<AnyType>:$operands);

  let builders = [
    OpBuilder<(ins), [{ /* nothing to do */ }]>,
  ];

  let assemblyFormat = "attr-dict ($operands^ `:` type($operands))?";
}

#endif  // IREE_DIALECT_LINALGEXT_OPS
