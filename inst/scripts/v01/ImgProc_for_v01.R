################################################################
## Load the package
################################################################
library(EBImage)
library(magick)
library(purrr)
library(magrittr)
library(filesstrings)
library(animation)

################################################################
## Image pre-processing
################################################################
processing_2d_image_train_test <- function(file, type="png", shape, filter="bilinear",
                                           normalize=FALSE, clahe=FALSE, GammaVal=1.0){
  image <- EBImage::readImage(file, type=type)
  image <- resize(image, w = shape[1], h = shape[2], filter = filter)
  if(normalize){image <- normalize(image)}
  if(clahe){image <- clahe(image)}
  if(is.numeric(GammaVal)){image <- image^GammaVal}
  array(image, dim=c(shape[1], shape[2], shape[3]))
}

processing_2d_image_GT <- function(file, type="png", shape){
  image <- EBImage::readImage(file, type=type)
  image <- resize(image, w = shape[1], h = shape[2], filter = "none")
  array(image, dim=c(shape[1], shape[2], shape[3]))
}

################################################################
##Download image data
################################################################
#if(!dir.exists("BioImageDbs_Data")){ dir.create("BioImageDbs_Data") }
#download.file("https://gist.githubusercontent.com/kumeS/6f67b4b9085b3d2580c51b8ae4953beb/raw/8a00395c533bd8bb16a284568d82b3318b84d3a2/gdrive_download.sh", destfile="gdrive_download.sh")
#id <- c("1kxT5ebWKLJs2Z2uNuiT4mvjuSpC2RF3_",
#        "1MRdPXshHQshYszUpcLvNf-FjCkPCGdLo",
#        "1585YNfUxZ-u8MqddEZx8cD1uihGhmdmr",
#        "1JGPe_P4hV4lCTKC9lOErE6nvsZ6AqIFt",
#        "1zu_WaPHTJr04snkWNY7fM22eZHcFHjzE")
#for(n in 1:length(id00)){
#system(paste0("source gdrive_download.sh; gdrive_download ", id[n], " ./output.zip"))
#system("mv *.zip ./BioImageDbs_Data; unzip ./BioImageDbs_Data/output.zip")
#}

################################################################
## R Functions to read image files and convert them to the Rds files
## Convert images to the 5D array
################################################################
ImgDataImport_3d_seg <- function(WIDTH  = 256, HEIGHT = 256, Z=-1, CHANNELS = 1,
                       data="./BioImageDbs_Data",
                       path01="id0001_Brain_CA1_hippocampus_region",
                       path02="01_Training",
                       Original_path="OriginalData",
                       GroundTruth_path="mitochondria_GT",
                       OriginalDataOnly=FALSE){
    DataDIR <- paste0(data, "/", path01, "/", path02)
    Original_PATH = paste0(DataDIR, "/", Original_path)
    GroundTruth_PATH = paste0(DataDIR, "/", GroundTruth_path)

    SHAPE = c(WIDTH, HEIGHT, CHANNELS)

    #Original Data
    m0 <- paste0(Original_PATH, "/", dir(Original_PATH))
    m1 <- length(paste0(Original_PATH, "/", dir(Original_PATH)))
    DatX <- c()
    if(Z== -1){Z <- length(dir(m0[1]))}
    for(n in seq_len(m1)){
    ImageFileTrain = paste0(m0[n], "/", dir(m0[n]))[1:Z]
    X = map(ImageFileTrain, processing_2d_image_train_test, shape = SHAPE)
    DatX[[n]] <- simplify2array(X)
    }

    xTensor1 <- simplify2array(DatX)
    xTensor2 <- aperm(xTensor1, c(5, 1, 2, 4, 3))

    if(!OriginalDataOnly){
    #Teacher Data
    m2 <- paste0(GroundTruth_PATH, "/", dir(GroundTruth_PATH))
    m3 <- length(paste0(GroundTruth_PATH, "/", dir(GroundTruth_PATH)))
    DatY <- c()
    for(n in seq_len(m3)){
    ImageFileTrain = paste0(m2[n], "/", dir(m2[n]))[1:Z]
    Y = map(ImageFileTrain, processing_2d_image_GT, shape = SHAPE)
    DatY[[n]] <- simplify2array(Y)
    }

    yTensor1 <- simplify2array(DatY)
    yTensor2 <- aperm(yTensor1, c(5, 1, 2, 4, 3))

    Img <- list(Original=xTensor2, GroundTruth=yTensor2)
    return (Img)

    }else{
    Img <- list(Original=xTensor2)
    return (Img)
    }
}

####################################################################################
# Convert the 5D array to the .Rds file
####################################################################################
DataImport_3d_seg <- function(WIDTH = 1024, HEIGHT = 769, Z=-1, CHANNELS = 1,
                       data="./BioImageDbs_Data",
                       path01="id0001_Brain_CA1_hippocampus_region",
                       Original_path="OriginalData",
                       GroundTruth_path="mitochondria_GT",
                       OriginalDataOnlyinTest=FALSE,
                       FileName="id0001_Brain_CA1_hippocampus_region",
                       Binary=FALSE){
a <- ImgDataImport_3d_seg(WIDTH  = WIDTH, HEIGHT = HEIGHT, Z=Z, CHANNELS = CHANNELS,
                 data=data, path01=path01, path02="01_Training",
                 Original_path=Original_path, GroundTruth_path=GroundTruth_path)
#str(a)
names(a) <- c("Train_Original", "Train_GroundTruth")

if(!OriginalDataOnlyinTest){
b <- ImgDataImport_3d_seg(WIDTH  = WIDTH, HEIGHT = HEIGHT, Z=Z, CHANNELS = CHANNELS,
                 data=data, path01=path01, path02="02_Testing",
                 Original_path=Original_path, GroundTruth_path=GroundTruth_path)
#str(b)
names(b) <- c("Test_Original", "Test_GroundTruth")
}else{
b <- ImgDataImport_3d_seg(WIDTH  = WIDTH, HEIGHT = HEIGHT, Z=Z, CHANNELS = CHANNELS,
                 data=data, path01=path01, path02="02_Testing",
                 Original_path=Original_path, GroundTruth_path=GroundTruth_path,
                 OriginalDataOnly=TRUE)
#str(b)
names(b) <- c("Test_Original")
}

if(!Binary){
Img <- list(Train=a, Test=b)
saveRDS(Img, paste0(FileName, ".Rds"), compress = TRUE)
}else{
if(!OriginalDataOnlyinTest){
a$Train_GroundTruth[a$Train_GroundTruth > 0] <- 1
names(a) <- c("Train_Original", "Train_GroundTruth_Binary")

b$Test_GroundTruth[b$Test_GroundTruth > 0] <- 1
names(b) <- c("Test_Original", "Test_GroundTruth_Binary")

Img <- list(Train=a, Test=b)
saveRDS(Img, paste0(FileName, "_Binary.Rds"), compress = TRUE)
}else{
a$Train_GroundTruth[a$Train_GroundTruth > 0] <- 1
names(a) <- c("Train_Original", "Train_GroundTruth_Binary")

Img <- list(Train=a, Test=b)
saveRDS(Img, paste0(FileName, ".Rds"), compress = TRUE)
}
}
}

################################################################
## Convert images to the 4D array
################################################################
ImgDataImport_2d_seg  <- function(WIDTH = 256, HEIGHT = 256, CHANNELS = 1,
                       data="./BioImageDbs_Data",
                       path01="LM_id0001_DIC_C2DH_HeLa",
                       path02="01_Training",
                       Original_path="OriginalData",
                       GroundTruth_path="Cell_GroundTruth_8b" ){

    DataDIR <- paste0(data, "/", path01)
    Original_PATH = paste0(DataDIR, "/", path02, "/", Original_path)
    SHAPE = c(WIDTH, HEIGHT, CHANNELS)

    #01_Training
    m0 <- paste0(Original_PATH, "/", dir(Original_PATH))
    DatX <- c()

    X = map(m0, processing_2d_image_train_test, shape = SHAPE)
    #str(X)
    DatX <- simplify2array(X)
    #str(DatX)
    xTensor1 <- aperm(DatX, c(4, 1, 2, 3))
    #str(xTensor1)

    #02_Testing
    GroundTruth_PATH = paste0(DataDIR, "/", path02, "/", GroundTruth_path)
    m0 <- paste0(GroundTruth_PATH, "/", dir(GroundTruth_PATH))
    DatY <- c()

    Y = map(m0, processing_2d_image_train_test, shape = SHAPE)
    #str(Y)
    DatY <- simplify2array(Y)
    #str(DatY)
    yTensor1 <- aperm(DatY, c(4, 1, 2, 3))
    #str(yTensor1)

    Img <- list(Training=xTensor1, Test=yTensor1)
    #str(Img)

    return(Img)

}

####################################################################################
# Convert the 4D array to the .Rds file
####################################################################################
DataImport_2d_seg <- function(WIDTH = 512, HEIGHT = 512, CHANNELS = 1,
                       data="./BioImageDbs_Data",
                       path01="LM_id0001_DIC_C2DH_HeLa",
                       Original_path="OriginalData",
                       GroundTruth_path="Cell_GroundTruth_8b",
                       FileName="LM_id0001_DIC_C2DH_HeLa",
                       Binary=FALSE){
a <- ImgDataImport_2d_seg(WIDTH = WIDTH, HEIGHT = HEIGHT, CHANNELS = CHANNELS,
                       data=data,
                       path01=path01,
                       path02="01_Training",
                       Original_path=Original_path,
                       GroundTruth_path=GroundTruth_path)
names(a) <- c("Train_Original", "Train_GroundTruth")

b <- ImgDataImport_2d_seg(WIDTH = WIDTH, HEIGHT = HEIGHT, CHANNELS = CHANNELS,
                       data=data,
                       path01=path01,
                       path02="02_Testing",
                       Original_path=Original_path,
                       GroundTruth_path=GroundTruth_path)
names(b) <- c("Test_Original", "Test_GroundTruth")

if(!Binary){
Img <- list(Train=a, Test=b)
saveRDS(Img, paste0(FileName, ".Rds"), compress = TRUE)
}else{
a$Train_GroundTruth[a$Train_GroundTruth > 0] <- 1
names(a) <- c("Train_Original", "Train_GroundTruth_Binary")

b$Test_GroundTruth[b$Test_GroundTruth > 0] <- 1
names(b) <- c("Test_Original", "Test_GroundTruth_Binary")

Img <- list(Train=a, Test=b)
saveRDS(Img, paste0(FileName, "_Binary.Rds"), compress = TRUE)
}
}

