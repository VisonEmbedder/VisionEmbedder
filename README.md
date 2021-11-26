# VisionEmbedder

## Introduction

Key-value lookup plays an important role in lots of applications among all aspects of computer science, including distributed caching, cloud computing, lookup files, network algorithms and so on. VisionEmbedder is a fast, efficient and low-memory key-value storage solution. It outperforms prior art such as Othello, ColoringEmbedder and Ludo in many key aspects including memory cost, lookup throughput, update throughput. Besides, it's more stable than  others and encounter update failure in rare cases. 

## About this repo

* `src` contains source code for `VisionEmbedder`
* `VisionEmbedder_Theoretical Analysis` is the technical report for VisionEmbedder. We prove that the update procedure will converge in the end if $\frac{m}{n} \geq 1.756$ and the probability of update failure is $O(\frac{1}{n^2})$

## Requirements

* `g++`

## How to make

* `cd src`
* `g++ demo.cpp -o demo`
* `./demo`