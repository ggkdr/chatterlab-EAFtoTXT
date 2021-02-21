### Converts annotated ELAN files (.eaf) to plaintext list (.txt)

library(shiny)
library(shinythemes)
library(tidyverse)
library(xml2)

## 1 - import .eaf input file
input_eaf <- read_xml("test.eaf")


## 2 - create dataframe with time data
##
## <TIME_ORDER>
### <TIME_SLOT TIME_SLOT_ID="" TIME_VALUE="">

time_data <- data.frame(character(0),numeric(0))
time_data <- setNames(time_data,c("slot_id","value"))

# get XML node for TIME_ORDER (1 root node)
time_order <- xml_find_first(input_eaf,"TIME_ORDER")

# get XML nodeset for TIME_SLOT (N leaf nodes)
time_slots <- xml_children(time_order)

# loop through each TIME_SLOT
for (time_slot in time_slots)
{
  # get attributes
  time_slot_id <- xml_attr(time_slot,"TIME_SLOT_ID")
  time_value <- xml_attr(time_slot,"TIME_VALUE")
  time_value <- as.numeric(time_value)
  
  # load attributes into time_data
  time_data <- rbind(time_data,
                     data.frame("slot_id" = time_slot_id,
                       "value" = time_value))
}


## 3 - create dataframe with annotations
##
## annotation format depends on LINGUISTIC_TYPE_REF:
##
## format 1:
### <TIER LINGUISTIC_TYPE_REF="transcription" PARTICIPANT="" TIER_ID="">
#### <ANNOTATION>
##### <ALIGNABLE_ANNOTATION ANNOTATION_ID="" TIME_SLOT_REF1="" TIME_SLOT_REF2="">
###### <ANNOTATION_VALUE>
##
## format 2:
### <TIER LINGUISTIC_TYPE_REF="" PARENT_REF="" PARTICIPANT="" TIER_ID="">
#### <ANNOTATION>
##### <REF_ANNOTATION ANNOTATION_ID="" ANNOTATION_REF="">
###### <ANNOTATION_VALUE>

anno_data <- data.frame(character(0),character(0),character(0),numeric(0),numeric(0),numeric(0),character(0))
anno_data <- setNames(anno_data,c("participant","tier_id","time1","time2","time_total","annotation_value"))

# get XML nodeset for ANNOTATION (N leaf nodes)
anno_ns <- xml_find_all(input_eaf,"//TIER/ANNOTATION") # "//" = start from root directory

# loop through each ANNOTATION
for (anno in anno_ns)
{
  tier <- xml_parent(anno)
  
  # get attributes of tier
  linguistic_type_ref <- xml_attr(tier,"LINGUISTIC_TYPE_REF")
  tier_id <- xml_attr(tier,"TIER_ID")
  participant <- xml_attr(tier,"PARTICIPANT")
  
  # get attributes according to format 1 (above)
  if (linguistic_type_ref == "transcription")
  {
    alignable_anno <- xml_child(anno)
    
    # get annotation_id
    annotation_id <- xml_attr(alignable_anno,"ANNOTATION_ID")
    
    # get time1, time2, time_total
    time_slot_ref1 <- xml_attr(alignable_anno,"TIME_SLOT_REF1")
    time_slot_ref2 <- xml_attr(alignable_anno,"TIME_SLOT_REF2")
    time1 <- time_data[time_data$slot_id == time_slot_ref1,"value"] # get value from slot_id
    time2 <- time_data[time_data$slot_id == time_slot_ref2,"value"] # get value from slot_id
    time_total <- time2-time1
    
    # get annotation_value
    annotation_value <- xml_text(xml_child(alignable_anno))
  }
  # get attributes according to format 2 (above)
  else
  {
    ref_anno <- xml_child(anno)
    
    # get annotation_id
    annotation_id <- xml_attr(ref_anno,"ANNOTATION_ID")
    
    # get time1, time2, time_total
    # *for format 2, annotation_ref specifies the already-seen annotation_id containing anno's time data
    annotation_ref <- xml_attr(ref_anno,"ANNOTATION_REF")
    time1 <- anno_data[anno_data$annotation_id == annotation_ref,"time1"] # get time1 from anno_id
    time2 <- anno_data[anno_data$annotation_id == annotation_ref,"time2"] # get time2 from anno_id
    time_total <- anno_data[anno_data$annotation_id == annotation_ref,"time_total"]
    
    # get annotation_value
    annotation_value <- xml_text(xml_child(ref_anno))
  }
  
  # load attributes into anno_data
  anno_data <- rbind(anno_data,
                     data.frame("tier_id" = tier_id,
                                "participant" = participant,
                                "annotation_id" = annotation_id,
                                "time1" = time1,
                                "time2" = time2,
                                "time_total" = time_total,
                                "annotation_value" = annotation_value))
}

## 4 - file export
# remove annotation_id column - we're done with it
anno_data$annotation_id = NULL

# export .txt output file
write.table(anno_data,
            "output.txt",
            sep="\t",
            quote=FALSE,
            row.names=FALSE,
            col.names=FALSE)