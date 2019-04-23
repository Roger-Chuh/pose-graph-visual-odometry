This repository includes code to compare the performance of two different approaches to graph-based visual odometry using RGB-D data. The approaches differ in their methods of obtaining initial guesses of the rigid body transformations between keyframes. An indirect front-end uses SURF to determine matched features between frames. These matches are used to create new keyframes and loop closures. A direct front-end instead uses Gauss-Newton, an iterative approach for computing the transformations. Both front-end methods send their initial guesses of the transformations relating each pair of connected keyframes to the same back-end method that jointly optimizes and updates each transformation using a pose synchronization method. The back-end also requires the loop closures between keyframes, which are only determined through our indirect front-end.

How to run a simple test: