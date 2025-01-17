# save as 'get_info.r'
# batch script run by analysis.r script with 1 argument
# Rscript path/get_info.r tmp/path/get_info.info
# retrieves information needed for hit_candidate.r from E-CRISP/Re-Evaluation



library(tidyverse)


##############
#### init ####
##############
# path of info file is in 1st argument
# load info file and ecrisp.genome.R function
infoFile <- commandArgs(TRUE)[1] #"./newDir/get_info.info"  
x <- scan(infoFile, what="", sep="\n")
info <- list()
xlist <- strsplit(x, split = ";", fixed = TRUE) 

for( i in 1:length(xlist) ){
  info[[xlist[[i]][1]]] <- xlist[[i]][-1]
}

logDir <- info$logDir
userID <- info$userID
userDir <- info$userDir
eCRISP <- info$ecrisp

wd <- getwd()


# create log for troubleshooting
logFile <- file.path(logDir, "get_info.log")
log <- c(paste(userID, ": get_info.r starting at", Sys.time()),
         paste(userID, ": signature is", info$signature))
if( !file.exists(logFile) ){
  write(log, logFile)  
} else {
  write(log, logFile, append = TRUE)  
}


###############
#### Write ####
###############
# use this function for writing anything (log file info file)
# checks whether this get_info.r process is still the newest by comparing signatures
# written when starting analysis.r
# if yes get_info.r can actually write, if no get_info.t quits itself
# necessary arguments are lines, fileName, bAppend
# arguments   lines       chr arr with content to be written
#             fileName    chr with path of file to write in
#             bAppend     bool whether to append file or overwrite
#             ID          chr user ID (session)
#             logFilename chr path of log file
#             oldSign     chr of signature this get_info.r was started with
#             signPath    chr of path for file containing newest signature
# side effects  writes/reads on files
Write <- function( lines, fileName, bAppend, 
      ID = userID, logFilename = logFile, oldSign = info$signature, signPath = file.path(userDir, "analysis.sign") ){
  
  activeSign <- scan(signPath, what = "", sep = "\n", quiet = TRUE)
  if( activeSign == oldSign ){
    write(lines, fileName, append = bAppend)
  } else {
    out <- c(
      paste(ID, ": get_info.r was started with signature", oldSign),
      paste(ID, ": active signature is", activeSign),
      paste(ID, ": quit this get_info.r process at", Sys.time())
    )
    write(out, logFilename, append = TRUE)
    quit(save = "no", status = 0)
  }
}






##################
#### Progress ####
##################
# this process works in the background
# there will only be 2 progress statuses
# 0.1 showing the app that this process was started
# 1 showing the app that this process is finished
# give app poll handle (each 0.5s) 0.5s time to realize process has started
progress <- 0.1
outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)
Sys.sleep(1)

 




##############
#### load ####
##############
# load cp.rds created by analysis.r before
# load only the car functions needed
Write(paste(userID, ": WD ", wd), logFile, bAppend = TRUE)
Write(paste(userID, ": loading cp.rds and reannotation functions"), logFile, bAppend = TRUE) 

load(file.path(userDir, "cp.rds"))

Write(paste(userID, ": source in ", info$funDir), logFile, bAppend = TRUE)
source(file.path(info$funDir, "ecrisp.genome.R"))
source(file.path(info$funDir, "car.genome.R"))
source(file.path(info$funDir, "raw.genes.R"))



progress <- 0.3
outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)


###########################################################################
#### contact E-CRISP or get pre-defined reannotation file ####
###########################################################################
# call E-CRISP and write on cp environment and create R object
# writes: cp$ecrisp, cp$genomic.gene, cp$genomic.sgrna
# debug = TRUE : print debug information
# value is saved in CRISPRAnalyzeRpools.genomic.view
# that function runs for > 10 mins if re-annotation needs to be retrieved from E-CRISP.org!
Write(paste(userID, ": reannotating sgRNAs"), logFile, bAppend = TRUE)
Write(paste(userID, ": Databasepath is ", info$databasepath), logFile, bAppend = TRUE)
Write(paste(userID, ": Access to it is ", file.access(info$databasepath)), logFile, bAppend = TRUE)

# First we check for a pre-made reannotation file for all supplied CRISPR libraries, if custom we have to go for re-evaluation
if(info$libSelected %in% info$libsAvailable && info$libSelected != "CUSTOM")
{
  Write(paste(userID, ": Pre-selected Screening Library used -  ", info$libName), logFile, bAppend = TRUE)
  Write(paste(userID, ": Libpath -  ", info$libPath), logFile, bAppend = TRUE)
  lib_load <- sub(pattern = "\\.fasta",x = info$libName,replacement = ".RDS")
  # So we go and load the pre-annotated file!
  Write(paste(userID, ": Loading Pre-selected Screening Library -  ", file.path(info$scriptDir, "external", lib_load)), logFile, bAppend = TRUE)
  ecrispresult <- try(readRDS(file = file.path(info$scriptDir, "external", lib_load)))
  
  if(class(ecrispresult) == "try-error")
  {
    preload <- 0
    Write(paste(userID, ": Annotation could not be loaded, reverting to re-annoation"), logFile, bAppend = TRUE)
    
  } else {
    preload <- 1
    # We go and proceed with loaded file
    Write(paste(userID, ": Annotation Loaded - merging with analysis data"), logFile, bAppend = TRUE)
    
    progress <- 0.5
    outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
    Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)
    
    if(identical(cp$miaccs$g.convert, TRUE) )
    {
      #ecrispresult$design <-
      sgrnas <- data.frame("design.old" = rownames(cp$readcount),
                           "design.new" = cp$readcount$design)
      colnames(sgrnas) <- c("design.old","design.new")
      #rownames(sgrnas) <- sgrnas$design

      ecrispresult <- merge(x = ecrispresult, y = sgrnas, by.x="design", by.y="design.old", all.x = TRUE)
      ecrispresult$design <- ecrispresult$design.new
      ecrispresult$design.new <- NULL
      ecrispresult$design.old <- NULL
      sgrnas <- NULL

    }
    
    ecrispresult <- merge.data.frame(ecrispresult, cp$readcount[,c("gene","design")], by.x = "design", by.y="design",all.x = TRUE, all.y=FALSE)
    # ecrispresult$gene.y <-  NULL
    # colnames(ecrispresult) <- c("design", "chr","Start", "End", "Gene.targets", "Spec.Score",
    #                             "Anno.Score","Eff.Score","Matchstring","Sequence","Direction","CDS_score",
    #                             "exon_score","seed_GC","doench_score","xu_score","doench_30_mer","gene")
    #print("merged ecrisp")
    Write(paste(userID, ": Annotation successfully merged"), logFile, bAppend = TRUE)
    progress <- 0.6
    outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
    Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)
    
    #remove missing strand informaiton with *
    Write(paste(userID, ": Replace missing strand information"), logFile, bAppend = TRUE)
    
    
    #remove missing strand informaiton with *
    ecrispresult[ecrispresult$Direction == "","Direction"] <- "*"
    ecrispresult[ecrispresult$Direction == "fw","Direction"] <- "+"
    ecrispresult[ecrispresult$Direction == "rc","Direction"] <- "-"
    
    # make chromosomes work with gviz
    Write(paste(userID, ": Make chromosomes working with Ensembl"), logFile, bAppend = TRUE)
    
    ecrispresult <- ecrispresult %>% dplyr::mutate(chr = ifelse( test = grepl(pattern = "chr.*" , x=chr), yes = chr, no = sub(x=chr , pattern = "^(\\d+|\\w)$",replacement = "chr\\1" ) )) 
    
    Write(paste(userID, ": store in cp environment"), logFile, bAppend = TRUE)
    # Store ecrisp table
    cp$ecrisp = as.data.frame(ecrispresult, stringsAsFactors = FALSE)
    
    progress <- 0.7
    outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
    Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)
  }
  
} else {
  preload = 0
}

# PRE-LOAD DID NOT WORK OR CUSTOM LIBRARY USED
Write(paste(userID, ": Preload Status is ", preload), logFile, bAppend = TRUE)
if(preload == 0)
{
  # Check if local installation of E-CRISP Re-evaluation is present
  if( file.access(file.path(info$scriptDir, "reannotate_crispr.pl"), mode=0) == 0 && file.access(file.path(info$databasepath), mode = 4) == 0 && info$databasepath != "")
  {
    Write(paste(userID, ": Access to local reannotate_crispr.pl and database folder is set"), logFile, bAppend = TRUE)
    res <- try(car.genome(
      outputdir=userDir, sequencefiles="libFile", databasepath=info$databasepath, organism = info$organism, nonseedlength = 0, mismatchesallowed = 2, reannotatescriptpath = info$scriptDir, logfile = logFile, btthreads = info$bt2Threads
    ))
    
    progress <- 0.5
    outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
    Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)
    
    # local re annotation NOT successfull!
    if(class(res) == "try-error")
    {
      Write(paste(userID, ": Local reannotation was not successfull, sending to E-CRISP"), logFile, bAppend = TRUE)
      Write(paste(userID, ": Error # ", res[1]), logFile, bAppend = TRUE)
      
      Write(paste(userID, ": Proxy set? - ", info$proxyurl, info$proxyport), logFile, bAppend = TRUE)
      #Write(paste(userID, ": Proxy set? - ", str(info$proxyurl), str(info$proxyport)), logFile, bAppend = TRUE)
     
      if(info$proxyurl != "NULL" && info$proxyport != "NULL")
      {
        
        if(info$proxyurl != "" && info$proxyport != "")
        {
          Write(paste(userID, ": Calling www.ecrisp.org with proxy"), logFile, bAppend = TRUE)
          res <- try( httr::with_config(httr::use_proxy(url = info$proxyurl, port = as.numeric(info$proxyport)),ecrisp.genome(
            debug = FALSE, dataframe = TRUE, reannotate=TRUE, write = FALSE, ecrisp = eCRISP, database=cp$miaccs$a.database, dataset = info$annoDataset, userid = userID, outputdir=userDir
          )))
        } else {
          Write(paste(userID, ": Calling www.ecrisp.org without proxy"), logFile, bAppend = TRUE)
          res <- try(ecrisp.genome(
            debug = FALSE, dataframe = TRUE, reannotate=TRUE, write = FALSE, ecrisp = eCRISP, database=cp$miaccs$a.database, dataset = info$annoDataset, userid = userID, outputdir=userDir
          ))
        }
       
      } else {
        
        Write(paste(userID, ": Calling www.ecrisp.org without proxy"), logFile, bAppend = TRUE)
        
        res <- try(ecrisp.genome(
          debug = FALSE, dataframe = TRUE, reannotate=TRUE, write = FALSE, ecrisp = eCRISP, database=cp$miaccs$a.database, dataset = info$annoDataset, userid = userID, outputdir=userDir
        ))
      }
      
      
    }
    
  } else # no execute permission of file or not there, so fallback to E-CRISP
  {
    Write(paste(userID, ": no access to local sgRNA re-evaluation - using E-CRISP"), logFile, bAppend = TRUE)
    
    if(info$proxyurl != "NULL" && info$proxyport != "NULL")
    {
      Write(paste(userID, ": Calling www.ecrisp.org with proxy"), logFile, bAppend = TRUE)
      res <- try( httr::with_config(httr::use_proxy(url = info$proxyurl, port = as.numeric(info$proxyport)),ecrisp.genome(
        debug = FALSE, dataframe = TRUE, reannotate=TRUE, write = FALSE, ecrisp = eCRISP, database=cp$miaccs$a.database, dataset = info$annoDataset, userid = userID, outputdir=userDir
      )))
      
    } else {
      Write(paste(userID, ": Calling www.ecrisp.org without proxy"), logFile, bAppend = TRUE)
      res <- try(ecrisp.genome(
        debug = FALSE, dataframe = TRUE, reannotate=TRUE, write = FALSE, ecrisp = eCRISP, database=cp$miaccs$a.database, dataset = info$annoDataset, userid = userID, outputdir=userDir
      ))
    }
    
    
    
  }

  if( class(res) == "try-error" ){
    outlog <- c(paste(userID, ": try-error occured"), 
                paste(userID, ":", res[1]), 
                paste(userID, ": get_info.r quit at", Sys.time()))
    Write(outlog, logFile, bAppend = TRUE)
    
    infos <- "Sorry, CRISPRAnalyzeR had trouble communicating with E-CRISP / Re-evaluation tool.<br/>"
    outInfo <- c(paste("progress", 1, sep = ";"), paste("info", infos, sep = ";"))
    Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)
    
    quit(save = "no", status = 1)
  }
  
  
  
}




progress <- 0.8
outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)


###################
#### raw genes ####
###################
# run raw.genes
# compute rawGenes dataframe as basis for sgRNA effects plots
Write(paste(userID, ": creating object rawGenes"), logFile, bAppend = TRUE)

res <- try(raw.genes(dataframe = TRUE, type = "offtarget", genes = NULL))

if( class(res) == "try-error" ){
  outlog <- c(paste(userID, ": try-error occured"),
      paste(userID, ":", res[1]),
      paste(userID, ": get_info.r quit at", Sys.time()))
  Write(outlog, logFile, bAppend = TRUE)
    
  infos <- "Sorry, CRISPRAnalyzeR could not reannotate your sgRNAs."
  outInfo <- c(paste("progress", 1, sep = ";"), paste("info", infos, sep = ";"))
  Write(outInfo, file.path(userDir, "get_info.info"), bAppend = FALSE)
  
  quit(save = "no", status = 1)
} else {
  rawGenes <- res
}






##############
#### save ####
##############
# save cp environment for further use by other processes
# set progress to 1
# save info file ^= signal to app
Write(paste(userID, ": writing cp environment and rawGenes as .rds file"), logFile, bAppend = TRUE)

save(cp, file = file.path(userDir, "cp.rds"))
saveRDS(rawGenes, file = file.path(userDir, "rawGenes.rds"))
saveRDS(cp$ecrisp, file = file.path(userDir, "ecrisp.rds"))

write(paste(userID, ": get_info.r quit at", Sys.time()), logFile, append = TRUE)

info$info <- ""
progress <- 1
outInfo <- c(paste("progress", progress, sep = ";"), paste("info", info$info, sep = ";"))
write(outInfo, file.path(userDir, "get_info.info"))

quit(save = "no", status = 0)














 
