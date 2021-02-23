## EAF → TXT (level 3)

With this tool, one can generate plaintext lists (.txt) of annotations contained in ELAN files (.eaf).

The output files will contain these unlabeled columns, in order: *Tier*, *Participant*, *Start Time*, *End Time*, *Total Time*, and *Annotation Value*.

## To run:
Double-click 'app.R' to open it (RStudio should launch automatically), and type into the R Console: ```shiny::runApp()```

Here's a demo:
<br><img src="./demonstration.gif" width="600">

## Output format:
The basename of an uploaded file will be used for the output file, which will also be downloaded into the same directory.

As an example, if you upload a.eaf and b.eaf from your Desktop:
- /Desktop/a.eaf
- /Desktop/b.eaf

then the final output will be two files, a.txt and b.txt, on your Desktop as well:
- /Desktop/a.txt
- /Desktop/b.txt

and your Desktop will contain all four files.

## Troubleshooting:
- For error "App dir must contain either app.R or server.R" in RStudio, **click in menubar**: ```Session > Set Working Directory > To Source File Location```
- For error "Unable to locate package NAME", **type in Console**: ```install.packages("NAME")```, replacing NAME with the package name

## Packages used:
- shiny
- shinyjs
- shinyFiles
- xfun
- xml2
- fs
