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


