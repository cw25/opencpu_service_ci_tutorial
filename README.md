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
* `docker/opencpu_config/Renviron`: _(optional)_ If your code relies on environment variables (via `Sys.getenv()`), you will need to set those variables here so that OpenCPU has access to them when it runs inside the Docker container
* `docker/opencpu_config/server.conf`: _(optional)_ Tells the OpenCPU to preload your R dependencies for better performance
* `tests/testthat.R`: The master test file that initiates tests for your package
* `tests/testthat/`: Your individual tests go in this directory
* `.gitignore`: Prevents your local junk (things like the .DS_Store files on your Mac) from being stored/tracked by Git
* `.travis.yml`: Travis integration settings
* `DESCRIPTION`: Metadata about the R package you are developing
* `Dockerfile`: Instructions for Docker on how to containerize your application
* `LICENSE`: Legal things that people rarely read
* `NAMESPACE`: R package instructions for importing other libraries and exporting your own functions
* `README.md`: Bad jokes and explanatory gymnastics



# R Code

For this tutorial, we will build a very simple service that takes in a text string and returns the average number of characters per word. The `stringr` package provides some very useful functions that will allow us to do this quickly and easily. Here is the code that we will build our service around:

```R
getMeanWordLength <- function(text) {
    words <- str_split(text, " ")
    word_lengths <- lapply(words, str_length)[[1]]
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

```R
import(stringr)
```

We have a bare bones R package now. Now let's look at how we can write and run tests to ensure that our package does what we expect it to do.



# testthat

Testing is easy in R, thanks to `testthat`. First, we create the master file (`tests/testthat.R`) that will trigger all of our tests.


```R
library(testthat)
library(stringstats)

test_check("stringstats")
```

Then, in the `tests/testthat/` directory, we can have as many tests as we need, split into as many files as we need. We just need to name them so they start with `test_` and end with `.R`. Let's create `tests/testthat/test_getMeanWordLength.R` to test the function we wrote.

```R
context("getMeanWordLength")

test_that("Mean word length is computed correctly", {
    text = "Do you want the mustache on or off"
    expect_equal(getMeanWordLength(text), 3.376)
})
```

The actual mean word length of our test string is 3.375, but this gives us an opportunity to see a test fail, and to look at a few helpful tips that will make development go more smoothly. From the project's root directory, we can test our project with the `R CMD CHECK .` command. This will trigger a build of our package (like Docker would do in production) and run our tests.

Here is the output from the testing portion of our build:


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

R produces _a lot_ of output when you build a package. Sometimes your test output scrolls away in the stdout flood, or helpful test output gets truncated. If you want to view the full results of your tests, R captures all test output in `..Rcheck/tests/testthat.Rout.fail` when your tests fail, and `..Rcheck/tests/testthat.Rout` when they succeed. If your build breaks, and R is complaining, the `..Rcheck` directory is a good place to start looking for answers.

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

```json
{
	"preload": ["stringr"]
}
```

I've also run into cases where I want OpenCPU to have access to environment variables. `docker/opencpu_config/Renviron` stores those variables.

(_Note:_ Our `.gitignore` file is set up to exclude this file, so if you are using it to store something sensitive like database access credentials, they won't wind up publicly accessible in Github.)

In this tutorial, we won't actually use `Renviron`, but if we did, it would look something like this:

```
MYSERVICE_VAR1=foo
MYSERVICE_VAR2=bar
```

Our R code would then be able to access those environment variables using calls to `Sys.getenv()`.



# Docker

I don't know about you, but I'm not too fond of setting up new server hardware. Rather than dedicate an entire production server to running OpenCPU, and doing all the hard work of installing and configuring it, OpenCPU provides an official `Dockerfile` to do it for us.

If you're not familiar with Docker, you can think of a Docker container as a stripped down virtual machine, containing only the bare minimum components necessary to run your service. Containerizing your service gives you some amazing advantages like tracking your server configuration changes via version control, fast spin-up of services, efficient auto-scaling of your services, etc.

We will need to setup two Docker-related files in order to build a Docker _image_ of our service. Once the image is built, we will spin up a container with our image and see OpenCPU in action. Let's start with our `Dockerfile`:


```Dockerfile
# Use the official OpenCPU Dockerfile as a base
FROM opencpu/base

# Put a copy of our R code into the container
WORKDIR /usr/local/src
COPY . /usr/local/src/app

# Move OpenCPU configuration files into place
COPY docker/opencpu_config/* /etc/opencpu/

# Run our custom install script to install R dependencies
RUN /usr/bin/R --vanilla -f app/docker/installer.R

# Install our code as an R package on the server
RUN tar czf /tmp/stringstats.tar.gz app/ \
  && /usr/bin/R CMD INSTALL /tmp/stringstats.tar.gz
```

Again, OpenCPU has done lots of the heavy lifting for us. The `opencpu/base` image takes care of the low-level setup and we only have to worry about our service. (If you're really curious to see the OpenCPU server's `Dockerfile`, you can take a look [here](https://hub.docker.com/r/opencpu/base/~/dockerfile/).)

In our `Dockerfile`, you may have noticed that there is a command that runs a custom install script, `docker/installer.R`. We will use that script to install our R package dependencies. For this tutorial, we only need to install `stringr` from CRAN:

```R
install.packages(c('stringr'), repos='http://cran.us.r-project.org', dependencies=TRUE)
```

If we wanted to install multiple CRAN packages, we would simply add them to our `install.packages()` call. We might also use `devtools::install_github()` to install R packages hosted on Github.

Let's build our Docker image! From inside the project directory, run the command `docker build -t stringstats .` and watch Docker do its magic. 

```
$ docker build -t stringstats .
Sending build context to Docker daemon  243.7kB
Step 1/6 : FROM opencpu/base
 ---> 9f6c992d11d8
Step 2/6 : WORKDIR /usr/local/src
 ---> Using cache
 ---> 90ca706a641d
Step 3/6 : COPY . /usr/local/src/app
 ---> 6ab2e5381552
Removing intermediate container 454e6a09e6c3
Step 4/6 : COPY docker/opencpu_config/* /etc/opencpu/
 ---> 9ebff403e548
Removing intermediate container 1373debe2889
Step 5/6 : RUN /usr/bin/R --vanilla -f app/docker/installer.R
 ---> Running in 971798f47f33

...(lots of output as R installs stringr and its dependencies)...

 ---> 58c99ee9cc7b
Removing intermediate container 971798f47f33
Step 6/6 : RUN tar czf /tmp/stringstats.tar.gz app/   && /usr/bin/R CMD INSTALL /tmp/stringstats.tar.gz
 ---> Running in fde9754b5566
* installing to library '/usr/local/lib/R/site-library'
* installing *source* package 'stringstats' ...
** R
** preparing package for lazy loading
** help
No man pages found in package  'stringstats' 
*** installing help indices
** building package indices
** testing if installed package can be loaded
* DONE (stringstats)
 ---> b8228a7adfc2
Removing intermediate container fde9754b5566
Successfully built b8228a7adfc2
Successfully tagged stringstats:latest
```

Now that we've built an image, let's launch a container: `docker run -d -p 8004:8004 stringstats`. OpenCPU provides a UI on port 8004, so we make sure to tell Docker to map that port to port 8004 on localhost. This will let us access the running container in our web browser for testing.

```
$ docker run -d -p 8004:8004 stringstats
448ee587c78a224749ab5d594c0a095eb13001e5e1b9441190a566fd136f615a
```

That long ID is your unique container ID, but I find it much easier to lean on `docker ps` to see my running containers, get their unique IDs and names, etc.

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                     NAMES
448ee587c78a        stringstats         "/bin/sh -c 'apach..."   3 minutes ago       Up 3 minutes        80/tcp, 443/tcp, 0.0.0.0:8004->8004/tcp   pensive_colden
```

Here's the moment of truth... let's open a web browser and test our running API. Browse to `http://localhost:8004/ocpu/test/` and you should see OpenCPU's test page:

![OpenCPU Test Page](./screenshots/opencpu_test_page.png?raw=true)

First, let's make sure that OpenCPU has our `stringstats` package installed. In the "HTTP Request Options" form, try this endpoint (leave the Method set to GET): `../library/stringstats/R/getMeanWordLength`

![OpenCPU GET Request Test](./screenshots/opencpu_test_get.png?raw=true)

When we test the request, it should succeed with code `HTTP 200 OK`:

![OpenCPU Successful GET Test](./screenshots/opencpu_http_200_ok.png?raw=true)

In production, consumers of our API obviously won't use the OpenCPU testing interface. If you want to directly hit the API itself, try browsing to `http://localhost:8004/ocpu/library/stringstats/R/getMeanWordLength/print`

![OpenCPU Direct GET Output](./screenshots/opencpu_get_print.png?raw=true)

We've been using `GET` requests, so instead of executing our code, OpenCPU is just showing us the underlying code for our endpoint. When we want to actually execute the code, we will use `POST` requests instead. Go back to the OpenCPU test interface and try a `POST` request.

* Set the Method to `POST`
* Use the "Add Parameter" button to add a `POST` argument
* Remember, the argument accepted by our R function was named `text`, so we set the "Param Name" to `text` also
* For the "Param Value", make sure to surround your text in quotes so it gets passed to the API correctly
* Click "Ajax Request"

![OpenCPU POST Test](./screenshots/opencpu_post_test.png?raw=true)

What the deuce is that output?! A bunch of weirdo file paths or URLs? That's not what we expected. Here are the URLs that popped up for me (they use temporary IDs, so yours will look just a bit different):

```
/ocpu/tmp/x074d9e56cf/R/getMeanWordLength
/ocpu/tmp/x074d9e56cf/R/.val
/ocpu/tmp/x074d9e56cf/stdout
/ocpu/tmp/x074d9e56cf/source
/ocpu/tmp/x074d9e56cf/console
/ocpu/tmp/x074d9e56cf/info
/ocpu/tmp/x074d9e56cf/files/DESCRIPTION
```

I won't go into detail on all of these, but the basic idea is that OpenCPU captures a number of different streams of information for every request. You can see the raw stdout output, the code block that was executed, the exact function call, etc. The `.val` URL is the one we would use to see the results of our API call, so I'll browse to `http://localhost:8004/ocpu/tmp/x074d9e56cf/R/.val` to view the output:

```
[1] 4.428571
```

It works! But wait, it redirected me! I wound up at `http://localhost:8004/ocpu/tmp/x074d9e56cf/R/.val/print`. To use this as a service, I'd want JSON output instead. Edit the URL and try `http://localhost:8004/ocpu/tmp/x074d9e56cf/R/.val/json`. You should see the same data presented as JSON.

This is all great for testing, but what about production? We don't want to hit the service twice for every request. Ideally, we would just send a single `POST` request to the endpoint we want, and get a JSON payload back without ever seeing those temporary IDs. In that case, we would send our `POST` request directly to: `http://localhost:8004/ocpu/library/stringstats/R/getMeanWordLength/json`

```
$ curl -k -H "Content-Type: application/json" -X POST -d '{"text": "This is a direct API request"}' http://localhost:8004/ocpu/library/stringstats/R/getMeanWordLength/json 
[3.8333]
```

When working with OpenCPU, I highly recommend keeping a link to the [OpenCPU API docs](https://www.opencpu.org/api.html) handy!



# Travis CI

The last thing we need to do is setup our [Travis CI](https://travis-ci.org/) integration. Once you've logged in to Travis, click on your avatar icon in the upper right to visit your account settings page. On that page, you'll see a list of your public Github repos, with handy instructions.

![Travis CI Begin](./screenshots/travis_begin.png?raw=true)

Just click the button-slider icon next to your repo's name and you should see a green check mark indicating that Travis has been enabled for your repo.

![Travis CI Enable](./screenshots/travis_enable.png?raw=true)

Now, click on the name of your repo to watch your builds. You won't see anything there yet because we also need to set up the `.travis.yml` file in our repo:

```yml
sudo: false
warnings_are_errors: false
language: r
cache: packages
```

Now that both sides are configured properly, the next time you commit and push changes to Github, Travis will automatically trigger a build. Here's what it looks like on the Travis side. The build status is colored yellow to indicate a build in progress.

![Travis CI Build In Progress](./screenshots/travis_yellow.png?raw=true)

After it completes, it will turn red upon failure or green upon success.

![Travis CI Build Complete](./screenshots/travis_green.png?raw=true)

Success! We now have a pipeline that takes us through development, testing, and CI. Actual deployment to production is left as an exercise for the reader ;-)


# Thanks

Many thanks to:

* Kyle Umstatter, our Illuminate Ed Ops guru, for patiently answering a gajillion questions
* Jeroen Ooms, for saving me so much time/effort with his hard work on OpenCPU
* The R community for their constant willingness to help
* You, for reading this

I'd love to hear your thoughts on this tutorial! You can find me on Twitter at [@iamchriswalker](https://twitter.com/iamchriswalker) or email me at [cwalker@illuminateed.com](mailto:cwalker@illuminateed.com)
