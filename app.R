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
library(shinythemes)
library(tidyverse)
library(xml2)
library(xfun)

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
    time2 <- all_annotations[all_annotations$annotation_id == annotation_ref,"time2"]
  }
  
  # calculate total_time
  time_total <- time2-time1
  
  # return single annotation in vector
  return(c(tier_id,participant,annotation_id,time1,time2,time_total,annotation_value))
}

## Takes in entire file's XML node & time data, and returns dataframe of all ANNOTATIONS
##
## example entry: tier_id=lex@CHI, participant=CHI, time1=202729, time2=205828,
##                time_total=3099, annotation_value=0
getAllAnnotationsFromXML <- function(xml_root_node,time_data)
{
  all_annotations <- data.frame(character(0),character(0),character(0),numeric(0),numeric(0),numeric(0),character(0))
  all_annotations <- setNames(all_annotations,c("tier_id","participant","time1","time2","time_total","annotation_value"))
  
  # get XML nodeset for ANNOTATION (N leaf nodes)
  anno_ns <- xml_find_all(xml_root_node,"//TIER/ANNOTATION") # "//" = start from root directory
  
  # loop through each ANNOTATION
  for (anno in anno_ns)
  {
    # append attributes to all_annotations
    anno_attrs <- getAnnotationDataFromXML(anno,time_data,all_annotations)
    all_annotations <- rbind(all_annotations,anno_attrs)
  }
  # don't want annotation_id in output file
  all_annotations$annotation_id <- NULL
  return(all_annotations)
}

## Takes in server-side datapath (from Shiny) of uploaded .eaf file, and returns dataframe of all its ANNOTATIONS
##
## output column order: tier_id, participant, start_time, end_time, total_time, value
convertEAFtoDf <- function(server_datapath)
{
  eaf_as_xml <- read_xml(server_datapath)
  time_data <- getTimeDataFromXML(eaf_as_xml)
  anno_data <- getAllAnnotationsFromXML(eaf_as_xml,time_data)
}

## Shiny app functionality
ui <- fluidPage(
  titlePanel("EAF to TXT File Converter"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("files", label="Choose eaf file(s)", multiple=FALSE)
    ),
    mainPanel(
      textOutput("uploads"),
      uiOutput("downloadIsActive")
    )
  )
)
server <- function(input, output) {
  eaf_uploads<-reactive({
    # code will need datapath, name to execute
    req(input$files$datapath)
    req(input$files$name)
    
    # these two will be same length
    datapaths <- input$files$datapath
    names <- input$files$name
    
    # dp is the full *server-side* datapath for an uploaded file
    for (i in 1:length(names))
    {
      dp = datapaths[[i]]
      n = names[[i]]
      
      if (file_ext(dp)=="eaf")
      {
        # computer OS only allows multiple file selection in same directory
        df <- convertEAFtoDf(dp)
        showNotification(paste(n, "successfully converted. Please click Download!"),duration=7,type="message")
        
        output$downloadData <- downloadHandler(
          filename = function() {
            paste(getwd(),with_ext(n,".txt"),sep="/")
          },
          content = function(file) {
            write.table(df,file,sep="\t",quote=FALSE,row.names=FALSE,col.names=FALSE)
            showNotification(paste(with_ext(n,".txt"),"successfully downloaded!"),duration=7,type="default")
          }
        )
        
        output$downloadIsActive <- renderUI({
          downloadButton('downloadData', 'Download .txt File')
        })
      }
      else
      {
        # if not .eaf file, send a friendly signal
        showNotification(paste(n, "is not in .eaf format. Please try uploading again!"),duration=7,type="error")
        
        output$downloadIsActive <- renderUI({})
      }
    }
  })
  output$uploads <- renderText(eaf_uploads())
}
shinyApp(ui, server)