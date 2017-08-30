# So, You Want to Build a REST API with R...

I recently found myself stuck. I had a slick bit of R code that I was using to generate some valuable stats,
but I had no way to get it into production. The app stack where I work is mostly LAMP, and honestly, anybody
who says they want to do statistical computing in PHP should seek medical attention.

In order to properly develop and deploy my service, I needed to be able to answer all the usual questions:

+ Can I efficiently develop and try out the code on my laptop?
+ Can I run unit tests against my code?
+ Can I easily wrap my code in a REST API?
+ Can I bundle everything together into a production-ready container?
+ Can I automate the testing of that container before it goes into production?

Luckily, we have all the pieces we need!

+ [R](https://www.r-project.org/) and its [packaging system](http://r-pkgs.had.co.nz/) allow for efficient local development
+ R's [testthat](http://r-pkgs.had.co.nz/tests.html) package allows us to test our R code
+ The amazing [OpenCPU](https://www.opencpu.org) project gives us an easy way to wrap R code with an API
+ OpenCPU also has [Docker](https://www.docker.com/) support so we can containerize our service
+ [Travis CI](https://travis-ci.com/) provides easy tools for automated testing of our Docker container



# An Anatomy Lesson

This Git repo can serve as a template for the layout of your project. This is the same file layout I've used for building my services at [Illuminate Education](https://www.illuminateed.com). It is organized as an R package, with a few add-ons for Docker and OpenCPU. Here's a quick rundown of what the various files and directories do:

* `R/`: Your R code goes in this directory
* `docker/installer.R`: Used to install any R dependencies your code might have. This will take the place of `library()` calls in your R code
* `docker/opencpu_config/Renviron`: If your code relies on environment variables (via `Sys.getenv()`), you will need to set those variables here so that OpenCPU has access to them when it runs inside the Docker container
* `docker/opencpu_config/server.conf`: Tells the OpenCPU server about your R dependencies so the libraries can be preloaded at server start time
* `tests/testthat.R`: The master test file that is responsible for executing individual tests
* `tests/testthat/`: Your individual R test files go in this directory
* `.gitignore`: Prevents your local junk (things like the .DS_Store files on your Mac) from being stored/tracked by Git
* `.travis.yml`: Required Travis integration settings
* `DESCRIPTION`: Metadata about the R package you are developing
* `Dockerfile`: Instructions for Docker on how to containerize your application
* `NAMESPACE`: R package instructions for importing libraries and exporting your own functions
* `README.md`: Bad jokes and explanatory gymnastics


