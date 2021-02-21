# Tool that takes in an ELAN file with annotations (input.eaf), and
# spits out a plaintext list of the annotations, categorized (output.txt)

library(shiny)
library(shinythemes)
library(tidyverse)
library(XML)

#* column order for output.txt: 1,2,3,4,5,6
#* requires single pass through the data

# input into TIME_DATA_FRAME
## from TIME_ORDER
### for each TIME_SLOT
#### time_slot_id: get_header(TIME_SLOT_ID)
#### time_value: get_header(TIME_VALUE)

# input into ANNOT_DATA_FRAME
## for each TIER in XML
###
### 1: get_header(TIER_ID)
### 2: get_header(PARTICIPANT)
###
#** guaranteed that all 'transcription' blocks come first
###
### if LINGUISTIC_TYPE_REF=='transcription'
##### for each ANNOTATION
#####
###### from ALIGNABLE_ANNOTATION
####### 3: TIME_DATA_FRAME.access(get_header(TIME_SLOT_REF1))
####### 4: TIME_DATA_FRAME.access(get_header(TIME_SLOT_REF2))
####### a_id: get_header(ANNOTATION_ID)
####### a_ref: NULL
####### 5: 4-3
####### 6: get(ANNOTATION_VALUE)
###
### else
#### for each ANNOTATION
####
##### from REF_ANNOTATION
###### a_id: get_header(ANNOTATION_ID)
###### a_ref: get_header(ANNOTATION_REF)
#***** this a_id will already be entered; can access T_S_R1,2 from there
###### 3: ANNOT_DATA_FRAME.access(3)
###### 4: ANNOT_DATA_FRAME.access(4)
###### 5: ANNOT_DATA_FRAME.access(5)
###### 6: get(ANNOTATION_VALUE)


