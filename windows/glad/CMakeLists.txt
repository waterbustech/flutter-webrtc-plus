cmake_minimum_required(VERSION 3.0)
project(Glad)

# Create the glad library from the source files
add_library(glad STATIC 
    src/glad.c
)

# Specify the include directory for glad
target_include_directories(glad PUBLIC include/)
