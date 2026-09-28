# IFS
The program has the potential to generate very cool shapes. A taste:     
<img src="https://github.com/DVN888/IFS/blob/main/Screenshots/SpiralEye.png" height="210">
<img src="https://github.com/DVN888/IFS/blob/main/Screenshots/Claw.png" height="210">
<img src="https://github.com/DVN888/IFS/blob/main/Screenshots/Spatter.png" height="210">

Behind the scenes there's thousands particles (in 3 dimensional space). In the beginning, three random 4x4 matrices are generated. Then, all particles are iterated over. With every iteration, every particle's coordinate vector is transformed by a randomly chosen matrix generated before. This is an approach similar to the Chaos Game, see [Wikipedia](https://en.wikipedia.org/wiki/Chaos_game). Currently the shape is rendered quite flat. You can only tell distance by the shading color being darker.

## Controls
**Turn On/Off:** starts a loop that continuously iterates over the particles     
**New Thing:** generates new random matrices     
**Draw:** displays the current state of the particles     
**Do n Steps:** does as many iterations as written in the SpinEdit Box     
**New + n Steps:** generates new matrices and does as many iterations as written in the SpinEdit Box
**>/<:** extends the form to show an option to print out the current matrices
**Superdooperrendering:** starts/stops loops which periodically render the particles and also creates new matrices *(buggy and CPU intense)*
**Camera Arrows:** rotate the particles
**Camera resets** *(bottom right)* **:** resets vertical or horizontal rotation, or resets all
**Zoom** *(middle right)* **:** zoom in, reset the zoom, zoom out


The default value for the SpinEdit Box is 15. Usually, if a convergent shape exists for the matrices, the particles converge at around 7 or 8 iterations.

## Try it out
Download the `.exe` file and run it. Was only tested on Windows 11.

More pictures:     
<img src="https://github.com/DVN888/IFS/blob/main/Screenshots/Bird.png" height="330">
<img src="https://github.com/DVN888/IFS/blob/main/Screenshots/ThreeTree.png" height="330">     
<img src="https://github.com/DVN888/IFS/blob/main/Screenshots/ScenicDeath.png" height="440">
