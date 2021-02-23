## EAF → TXT

With this tool, one can generate plaintext lists (.txt) of annotations contained in ELAN files (.eaf).

The output files will contain, in order: *Tier*, *Participant*, *Start Time*, *End Time*, *Total Time*, and *Annotation Value*.

## To run:
Double-click 'app.R' to open it (RStudio should launch automatically), and type into the R Console: 'shiny::runApp()'

Here's a demonstration:
![demonstration](demonstration.gif)

## Troubleshooting:
- If you receive the error "App dir must contain either app.R or server.R" in RStudio, *click*: Session > Set Working Directory > To Source File Location
- If you receive the error "Unable to locate package <NAME>", *type in Console*: install.packages("NAME"), replacing NAME with the package name

## Packages Used:
- shiny
- shinyjs
- shinyFiles
- tidyverse
- xml2
- fs
