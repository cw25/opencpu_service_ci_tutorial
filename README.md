# So, you want to build a REST API with R...

I recently found myself stuck. I had a slick bit of R code that I was using to generate some valuable stats,
but I had no way to get it into production. The app stack where I work is mostly LAMP, and honestly, anybody
who says they want to do statistical computing in PHP should seek medical attention.

In order to properly develop and deploy my service with continuous integration, I needed to be able to
answer all the usual questions:

+ Can I package up my R code to run in other environments?
+ Can I run unit tests against my code?
+ Can I easily wrap my code in a REST API?
+ Can I bundle everything together into a production-ready container?
+ Can I automate the testing of that container before it goes into production?

Luckily, we have all the pieces we need!

+ [R](https://www.r-project.org/) and its [packaging system](http://r-pkgs.had.co.nz/) help with portability
+ The [testthat](http://r-pkgs.had.co.nz/tests.html) package allows us to test our R code
+ The amazing [OpenCPU](https://www.opencpu.org) project gives us an easy way to wrap R code with an API
+ OpenCPU also has [Docker](https://www.docker.com/) support so we can containerize our service
+ [Travis CI](https://travis-ci.com/) provides easy tools for automated testing of our Docker container



# First, an anatomy lesson

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
* `LICENSE`: Legal things that people rarely read
* `NAMESPACE`: R package instructions for importing libraries and exporting your own functions
* `README.md`: Bad jokes and explanatory gymnastics



# R Code

For this tutorial, we will build a very simple service that takes in a text string and returns the average number of characters per word. The `stringr` package provides some very useful functions that will allow us to do this quickly and easily. Here is the code that we will build our service around:

```
getMeanWordLength <- function(text) {
    words = str_split(text, " ")
    word_lengths = lapply(words, str_length)[[1]]
    return(mean(word_lengths))
}
```

Our R code should live in the `R/` directory of our project, so we will place this code in `R/getMeanWordLength.R`. Now, we will need to complete the other files that the R packaging system expects: `DESCRIPTION` and `NAMESPACE`.

The `DESCRIPTION` file is pretty self-explanatory, but pay special attention to the `Depends:` and `Suggests:` lines. Our package depends on `stringr`, so we need to make that dependency explicit by including it in `Depends:`. Because we will also be using `testthat` for our unit tests, we need to name it in the `Suggests:` line. Here's what our `DESCRIPTION` file looks like:

```
Package: stringstats
Title: String Statistics API
Version: 1.0
Date: 2017-08-30
Authors@R: person("Christopher", "Walker", email = "cw25@me.com", role = c("aut", "cre"))
Author: Christopher Walker [aut, cre]
Maintainer: Christopher Walker <cw25@me.com>
Description: API for calculating simple statistics about text strings.
Depends: R, stringr
Suggests: testthat
License: MIT
Encoding: UTF-8
LazyData: true
```

We also need to update `NAMESPACE` to tell our package how to access the functions we need from the `stringr` package. Thankfully, it's a simple one-liner:

```
import(stringr)
```

We have a bare bones R package now. This sets a solid foundation, particularly where testing is concerned. Now let's look at how we can write and run tests to ensure that our package does what we expect it to do.



# testthat

Testing is easy in R, thanks to `testthat`. First, we create the master file (`tests/testthat.R`) that will trigger all of our tests.


```
library(testthat)
library(stringstats)

test_check("stringstats")
```

Then, in the `tests/testthat/` directory, we can have as many tests as we need, split into as many files as we need. We just need to name them so they start with `test_` and end with `.R`. Let's create `tests/testthat/test_getMeanWordLength.R` to test the function we made.

```
context("getMeanWordLength")

test_that("Mean word length is computed correctly", {
    text = "Do you want the mustache on or off"
    expect_equal(getMeanWordLength(text), 3.376)
})
```

The actual mean in this case is 3.375, but this gives us an opportunity to look at a few helpful tips that will make development go more smoothly. From the project's root directory, we can test our project with the `R CMD CHECK .` command. This will trigger a build of our package (like Docker would do in production) and run our tests. Let's see what happens:


```
* checking tests ...
  Running ‘testthat.R’
 ERROR
Running the tests in ‘tests/testthat.R’ failed.
Last 13 lines of output:
  Loading required package: stringr
  > 
  > test_check("stringstats")
  1. Failure: Mean word length is computed correctly (@test_getMeanWordLength.R#5) 
  getMeanWordLength(text) not equal to 3.376.
  1/1 mismatches
  [1] 3.38 - 3.38 == -0.001
  
  
  testthat results ================================================================
  OK: 0 SKIPPED: 0 FAILED: 1
  1. Failure: Mean word length is computed correctly (@test_getMeanWordLength.R#5) 
  
  Error: testthat unit tests failed
  Execution halted
* checking PDF version of manual ... OK
* DONE

Status: 1 ERROR, 2 WARNINGs, 2 NOTEs
```

R produces _a lot_ of output when you do a build or check. Sometimes your test output scrolls away in the stdout flood, or helpful test output gets truncated. If you want to view the full results of your tests, R captures all test output in `..Rcheck/tests/testthat.Rout.fail` when your tests fail, and `..Rcheck/tests/testthat.Rout` when they succeed. If your build breaks, and R is complaining, the `..Rcheck` directory is a good place to dig for answers.

Once our test is fixed, the end of the check looks like this instead:

```
* checking tests ...
  Running ‘testthat.R’
 OK
* checking PDF version of manual ... OK
* DONE

Status: 2 WARNINGs, 2 NOTEs
See
  ‘/Users/cwalker/Documents/Illuminate/Data Science/R Libraries/opencpu_service_ci_tutorial/..Rcheck/00check.log’
for details.
```

No more errors. Now we are ready to wrap our function in an API.


# OpenCPU

Docker is going to do most of the heavy lifting for us where OpenCPU is concerned. All we need to worry about is how to configure the OpenCPU server. OpenCPU generally works very well out of the box, but I'll share two things that I've found useful. (Both are optional, so you can skip them if you like.)

OpenCPU can accept runtime configuration options from a `server.conf` file. We will store that file at `docker/opencpu_config/server.conf` in our project and later we will tell Docker to inject it into our service container. I like to use `server.conf` to tell OpenCPU about my R dependencies in advance so it will preload those libraries at server startup. The format is simple JSON:

```
{
	"preload": ["stringr"]
}
```

I've also run into cases where I want OpenCPU to have access to environment variables. `docker/opencpu_config/Renviron` stores those variables.

(_Note:_ Our .gitignore file is set up to exclude this file, so if you are using it to store something like database access credentials, they won't wind up publicly accessible in Github for all eternity.)

In this tutorial, we won't actually use `Renviron`, but it looks something like this:

```
MYSERVICE_VAR1=foo
MYSERVICE_VAR2=bar
```




