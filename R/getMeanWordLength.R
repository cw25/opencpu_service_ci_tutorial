getMeanWordLength <- function(text) {
    words <- str_split(text, " ")
    word_lengths <- lapply(words, str_length)[[1]]
    return(mean(word_lengths))
}
