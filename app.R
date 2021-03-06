### Converts ELAN files (.eaf) to plaintext lists of their annotations (.txt) ###
##
## The relevant XML structure in .eaf files looks like:
##
## <ANNOTATION_DOCUMENT>
### <TIME_ORDER>
#### <TIME_SLOT TIME_SLOT_ID="" TIME_VALUE="">
###
### <TIER LINGUISTIC_TYPE_REF="transcription" PARTICIPANT="" TIER_ID="">
#### <ANNOTATION>
##### <ALIGNABLE_ANNOTATION ANNOTATION_ID="" TIME_SLOT_REF1="" TIME_SLOT_REF2="">
###### <ANNOTATION_VALUE>
###
### <TIER LINGUISTIC_TYPE_REF="" PARENT_REF="" PARTICIPANT="" TIER_ID="">
#### <ANNOTATION>
##### <REF_ANNOTATION ANNOTATION_ID="" ANNOTATION_REF="">
###### <ANNOTATION_VALUE>

library(shiny)
library(shinyjs)
library(shinyFiles)
library(xfun)
library(xml2)
library(fs)

#######################
### SCRIPTING LOGIC ###
#######################

## Takes in local filepath of .eaf file, and returns dataframe of all its ANNOTATIONS
##
## output column order: tier_id, participant, start_time, end_time, total_time, value
convertEAFtoDf <- function(filepath)
{
  eaf_as_xml <- read_xml(filepath)
  time_data <- getTimeDataFromXML(eaf_as_xml)
  anno_data <- getAllAnnotationsFromXML(eaf_as_xml,time_data)
  return(anno_data)
}

## Takes in entire file's XML node and returns dataframe containing all TIME_SLOT instances
##
## example entry: slot_id=ts1, value=1740
getTimeDataFromXML <- function(xml_root_node)
{
  time_data <- data.frame(character(0),numeric(0))
  time_data <- setNames(time_data,c("slot_id","value"))
  
  # get set of XML nodes of TIME_SLOT
  time_order <- xml_find_first(xml_root_node,"TIME_ORDER") # 1 parent node
  time_slots <- xml_children(time_order) # many child nodes
  
  # loop through each TIME_SLOT
  for (time_slot in time_slots)
  {
    # get attributes
    time_slot_id <- xml_attr(time_slot,"TIME_SLOT_ID")
    time_value <- as.numeric(xml_attr(time_slot,"TIME_VALUE"))
    
    # append attributes to time_data
    time_data <- rbind(time_data,
                       data.frame("slot_id" = time_slot_id,"value" = time_value))
  }
  return(time_data)
}

## Takes in annotation XML node, time data, & prior annotations, and
## returns vector with relevant attributes of single ANNOTATION
##
## example entry: tier_id=lex@CHI, participant=CHI, annotation_id=a880,
##          time1=202729, time2=205828, time_total=3099, annotation_value=0
getAnnotationDataFromXML <- function(xml_anno_node,time_data,all_annotations)
{
  tier <- xml_parent(xml_anno_node)
  
  # get attributes of tier
  tier_id <- xml_attr(tier,"TIER_ID")
  participant <- xml_attr(tier,"PARTICIPANT")
  
  # refer to top-of-doc for two possible XML structures of ANNOTATION
  anno_child <- xml_child(xml_anno_node)
  
  # get attributes of annotation
  annotation_id <- xml_attr(anno_child,"ANNOTATION_ID")
  annotation_value <- xml_text(xml_child(anno_child))
  
  # linguistic_type_ref determines if annotation has time data or if we must reference it
  # (i.e. in ELAN, annotations for xds@CHI are linked to annotations for CHI speech)
  linguistic_type_ref <- xml_attr(tier,"LINGUISTIC_TYPE_REF")
  if (linguistic_type_ref == "transcription") # contains time data
  {
    time_slot_ref1 <- xml_attr(anno_child,"TIME_SLOT_REF1")
    time_slot_ref2 <- xml_attr(anno_child,"TIME_SLOT_REF2")
    # access from time_data
    time1 <- time_data[time_data$slot_id == time_slot_ref1,"value"]
    time2 <- time_data[time_data$slot_id == time_slot_ref2,"value"]
  }
  else # does NOT contain time data, must reference from previous annotation
  {
    annotation_ref <- xml_attr(anno_child,"ANNOTATION_REF")
    # access from all_annotations
    time1 <- all_annotations[all_annotations$annotation_id == annotation_ref,"time1"]
    time1 <- as.numeric(time1)
    time2 <- all_annotations[all_annotations$annotation_id == annotation_ref,"time2"]
    time2 <- as.numeric(time2)
  }
  
  # calculate total_time
  time_total <- time2-time1
  
  # return single annotation in vector
  df <- c(tier_id,participant,annotation_id,time1,time2,time_total,annotation_value)
  df <- setNames(df,c("tier_id","participant","annotation_id","time1","time2","time_total","annotation_value"))
  return(df)
}

## Takes in entire file's XML node & time data, and returns dataframe of all ANNOTATIONS
##
## example entry: tier_id=lex@CHI, participant=CHI, time1=202729, time2=205828,
##                time_total=3099, annotation_value=0
getAllAnnotationsFromXML <- function(xml_root_node,time_data)
{
  all_annotations <- data.frame(character(0),character(0),character(0),numeric(0),numeric(0),numeric(0),character(0))
  all_annotations <- setNames(all_annotations,c("tier_id","participant","annotation_id","time1","time2","time_total","annotation_value"))
  
  # get XML nodeset for ANNOTATION (N leaf nodes)
  anno_ns <- xml_find_all(xml_root_node,"//TIER/ANNOTATION") # "//" = start from root directory
  
  # loop through each ANNOTATION
  for (anno in anno_ns)
  {
    # append attributes to all_annotations
    anno_attrs <- getAnnotationDataFromXML(anno,time_data,all_annotations)
    all_annotations <- rbind(all_annotations,anno_attrs)
    all_annotations <- setNames(all_annotations,c("tier_id","participant","annotation_id","time1","time2","time_total","annotation_value"))
  }
  # don't want annotation_id in output file
  return(subset(all_annotations,select=c("tier_id","participant","time1","time2","time_total","annotation_value")))
}

###############################
### SHINY APP FUNCTIONALITY ###
###############################
ui <- fluidPage(
  useShinyjs(),
  headerPanel(
    "EAF ➡ TXT"
  ),
  sidebarPanel(
    tags$p("This tool converts .eaf files to tab-delimited .txt files. Upload as many files as you'd like, then click Download!"),
    tags$hr(),
    shinyFilesButton("files", "Select Files", "Select .eaf file(s) to convert to .txt", multiple = TRUE, viewtype = "list")
  ),
  mainPanel(
    # the 3 id's in quotes track events that trigger various server functions
    verbatimTextOutput("file_message"),
    uiOutput("conversion"),
    actionButton("download", label = "Download")
  )
)
server <- function(input, output, session) {
  # get directories for filepath navigation
  volumes <- c(Home = path_home(), getVolumes()())
  clear_message <- "No files are selected!"
  
  # action for "Select Files" button
  observe({
    shinyFileChoose(input, "files", roots = volumes, filetypes = c("eaf"), session = session)
  })
  
  # 1 - start with prompt
  output$file_message <- renderPrint({
    cat(clear_message)
  })
  
  # 2 - when "Select Files" is clicked, change message to list of filepaths
  # (input$files tracks button click)
  observeEvent(input$files,{
    filePaths <- parseFilePaths(volumes, input$files)$datapath
    message <- convertFilePathsToChar(filePaths)
    
    output$file_message <- renderPrint({
      cat(message)
    })
  })
  
  # 3 - when Download is clicked, change message back to prompt
  # (input$download tracks button click)
  observeEvent(input$download,{
    output$file_message <- renderPrint({
      cat(clear_message)
    })
  })
  
  # helper function for converting input$files to character string
  convertFilePathsToChar <- function(filePaths)
  {
    str <- character(0)
    for (fp in filePaths){str <- paste(str,fp,"\n")}
    return(str)
  }
  
  # when Download is clicked, run conversion process
  # (input$download tracks button click)
  downloadFiles <- eventReactive(input$download, {
    req(input$files)
    filePaths <- parseFilePaths(volumes, input$files)$datapath
    
    # conversion of each file
    for (fp in filePaths)
    {
      df <- convertEAFtoDf(fp)
      new_fp <- with_ext(fp,".txt")
      write.table(df,new_fp,sep="\t",quote=FALSE,row.names=FALSE,col.names=FALSE)
      showNotification(paste(new_fp,"successfully downloaded!"),duration=7,type="message")
    }
  })
  
  # render UI changes from downloadFiles 
  output$conversion <- renderUI({downloadFiles()})
}
shinyApp(ui, server)