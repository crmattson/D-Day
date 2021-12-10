#####Data distribution R script
#Created by: Cathy Mattson affiliated with ADFG ADU
#runs off of java script/oracle pulls from AEIGIS and exports to an excel file
#The only thing that the user will need to change is which Region to select on line 35

#####Required packages that will autotmaticall be installed if you don't havee them
while(!require(RJDBC)){install.packages("RJDBC")}
while(!require(tidyverse)){install.packages("tidyverse") }
while(!require(lubridate)){install.packages("lubridate")}
while(!require(shinythemes)){install.packages("shinythemes")}



#####This will give you the required library for all of the java script files that are needed to pull from our database directly
if(file.exists("C:/R/Required_library")){
} else {
  unzip("Required_library.zip",overwrite = FALSE,exdir = "C:/R")
}
.jinit()
rJava::.jaddClassPath("C:\\R\\Required_library\\ojdbc8.jar") #R uses backwards 


#This sets up a connection between oracle and R

jdbcDriver =JDBC("oracle.jdbc.OracleDriver",classPath="C:/R/Required_library/ojdbc8.jar")
host <- "db-cwtoto.dfg.alaska.local"
port <- "1521"
svc <- "DFGCWTOTOP.500040564.us1.internal"
protocol <-"jdbc:oracle:thin:"
url <- paste0(protocol,"@",host,":",port,"/",svc)
jdbcConnection =dbConnect(jdbcDriver, url, user="adu_reporter",password="gunghayfatchoy")

#### set up query ####
## This is the only line that you need to change if you are doing region 1 or region 2
region <- "1"
#adu_reading.release_authoritative <- "1"
r_date<- "11/25/2021"
gnoqry<-paste0("select
adu_sample.region_code as region,
to_char(adu_sample.date_sampled, 'mm/dd/yyyy') as sample_date,
adu_specimen.field_species_code as field_species,
adu_specimen.lab_species_code as lab_species,
adu_reading.sample_id as sample_id,
to_number(adu_reading.specimen_id) as specimen_number,
adu_reading.age as age,
to_number(adu_reading.readability_code) as readability,
user_status.reader_code as age_reader_code
from adu_specimen
inner join adu_sample on adu_specimen.year=adu_sample.year and adu_specimen.sample_id=adu_sample.sample_id
inner join adu_reading on adu_specimen.year=adu_reading.year and adu_specimen.sample_id=adu_reading.sample_id and adu_specimen.specimen_id=adu_reading.specimen_id
inner join user_status on adu_reading.userid=user_status.userid
where adu_sample.region_code='",region,"' and adu_reading.release_authoritative='1' and adu_reading.release_date>to_date('",r_date,"' ,'mm/dd/yyyy') 
order by adu_reading.sample_id, cast(adu_reading.specimen_id as numeric)") 


dday_data <- RJDBC::dbGetQuery(jdbcConnection, gnoqry)
discon <- dbDisconnect(jdbcConnection)
dday_data[is.na(dday_data)] <- ""  
dday_data <- rename(dday_data, "Region"=REGION, "Sample Date"=SAMPLE_DATE, "Field Species"=FIELD_SPECIES, "Lab Species"=LAB_SPECIES, "Sample ID"=SAMPLE_ID, "Specimen Number"=SPECIMEN_NUMBER, "Age"=AGE, "Readability"=READABILITY, "Age Reader Code"=AGE_READER_CODE)

####This sets up the customization of the pivot table 
createCustomTheme <- function(parentPivot=NULL, themeName="greyscale") {
  pivotStyles <- PivotStyles$new(parentPivot=parentPivot, themeName=themeName)
  # borders in black
  pivotStyles$addStyle(styleName="Table", list(
    "display"="table",
    "border-collapse"="collapse",
    "border"="2px solid #000000"
  ))
  # column headings in grey
  pivotStyles$addStyle(styleName="ColumnHeader", list(
    "font-family"="\"Times New Roman\", Times New Roman, monospace",
    "font-size"="0.75em",
    "font-weight"="bold",
    padding="2px",
    "border"="2px solid #000000",
    "vertical-align"="middle",
    "text-align"="center",
    "font-weight"="bold",
    color="#000000",
    "background-color"="#C9C9C9",
    "xl-wrap-text"="wrap"
  ))
  # row headings 
  pivotStyles$addStyle(styleName="RowHeader", list(
    "font-family"="\"Times New Roman\", Times New Roman, monospace",
    "font-size"="0.75em",
    
    padding="2px 8px 2px 2px",
    "border"="1px solid #000000",
    "vertical-align"="middle",
    "text-align"="left",
    
    color="#000000",
    "background-color"="#FFFFFF",
    "xl-wrap-text"="wrap"
  ))
  # cells
  pivotStyles$addStyle(styleName="Cell", list(
    "font-family"="\"Times New Roman\", Times New Roman, monospace",
    "font-size"="0.75em",
    padding="2px 2px 2px 8px",
    "border"="1px solid #000000",
    "text-align"="right",
    color="#000000",
    0
  ))
  # totals 
  pivotStyles$addStyle(styleName="Total", list(
    "font-family"="\"Times New Roman\", Times New Roman, monospace",
    "font-size"="0.75em",
    
    padding="2px 2px 2px 8px",
    "border"="1px solid rgb(84, 130, 53)",
    "text-align"="right",
    color="#000000",
    0
  ))
  
  pivotStyles$tableStyle <- "Table"
  pivotStyles$rootStyle <- "ColumnHeader"
  pivotStyles$rowHeaderStyle <- "RowHeader"
  pivotStyles$colHeaderStyle <- "ColumnHeader"
  pivotStyles$cellStyle <- "Cell"
  pivotStyles$outlineRowHeaderStyle <- "RowHeader"
  pivotStyles$outlineColHeaderStyle <- "ColumnHeader"
  pivotStyles$outlineCellStyle <- "Cell"
  pivotStyles$totalStyle <- "Total"
  
  return(invisible(pivotStyles))
}
# create the pivot table
library(pivottabler)
pt <- PivotTable$new()
pt$addData(dday_data)
pt$addColumnDataGroups("Field Species")
pt$addRowDataGroups("Sample ID")
pt$defineCalculation(calculationName="Grand Total", summariseExpression="n()")
pt$theme <- createCustomTheme(pt)
pt$evaluatePivot()
#####creating the excel workbook
library(openxlsx)
wb <- createWorkbook()
addWorksheet(wb, paste("Region ", region, " Age Data ", format(Sys.Date(), format="%m-%d-%y")))
addWorksheet(wb, "Summary")
pt$writeToExcelWorksheet(wb=wb, wsName="Summary", 
                         topRowNumber=1, leftMostColumnNumber=1, applyStyles=TRUE, showRowGroupHeaders=TRUE)
writeData(wb, paste("Region ", region, " Age Data ", format(Sys.Date(), format="%m-%d-%y")), x=dday_data)
yellowstyle <- createStyle(fontColour="#000000", bgFill="#FBFF08")
greenstyle <- createStyle(fontColour="#000000", bgFill="#05F04B")
conditionalFormatting(wb, paste("Region ", region, " Age Data ", format(Sys.Date(), format="%m-%d-%y")), cols=1:9, rows = 2:nrow(dday_data), rule= "$H2>5" , style=yellowstyle)
conditionalFormatting(wb, paste("Region ", region, " Age Data ", format(Sys.Date(), format="%m-%d-%y")), cols=1:9, rows = 2:nrow(dday_data), rule= "$E2<>$E1", style=greenstyle)
saveWorkbook(wb, paste(ifelse(region=="1","SEA_","SCA_"),format(Sys.Date(), format="%d%b%y"),".xlsx"), TRUE)



