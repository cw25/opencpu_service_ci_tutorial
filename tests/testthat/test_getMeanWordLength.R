context("getMeanWordLength")

test_that("Mean word length is computed correctly", {
    text = "Do you want the mustache on or off"
    expect_equal(getMeanWordLength(text), 3.375)
})
