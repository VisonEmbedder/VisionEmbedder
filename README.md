# VisionEmbedder

## Introduction

In key-value storage scenarios where storage space is at a premium, our focus is on a class of solutions that only store the value, which is highly space-efficient. While these solutions have proven their worth in distributed storage, networking, and bioinformatics, they still face two significant issues: one is that their space cost could be further reduced; the other is their are vulnerable to update failures, which can necessitate a complete table reconstruction.

To address these issues, we introduce VisionEmbedder, a compact key-value embedder with constant-time lookup, fast dynamic updates, and a near-zero risk of reconstruction. VisionEmbedder cuts down the storage requirement from 2.2L bits to just 1.6L bits per key-value pair with an L-bit value, and it significantly reduces the chance of update failures by a factor of n, where n is the number of keys (for instance, 1 million or more). The compromise with VisionEmbedder comes with a minor reduction in query throughput on certain data sizes. The enhancements offered by VisionEmbedder have been theoretically validated and are effective across any dataset. Additionally, we have implemented VisionEmbedder on both FPGA and CPU platforms, with all codes made available as open-source.

## About this repo

* `src` contains source code for `VisionEmbedder` in C++.
* `FPGA` contains the source code for FPGA Implementation.
* `VisionEmbedder_Theoretical Analysis` is the technical report for VisionEmbedder. We prove that the update procedure will converge in the end if m/n >= 1.756 and the probability of update failure is O(1/n^2). The practical extreme value of m/n is around 1.58.

## Requirements

* `g++`

## How to make

* `cd src`
* `g++ demo.cpp -o demo`
* `./demo`
