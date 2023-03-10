#!/usr/bin/env Rscript
#R

#proteomics analysis
#install packages and library--------------------------------------------------- 
package_install <- function(x){
    for( i in x ){
        #    require returns TRUE invisibly if it was able to load package
        if( ! require( i , character.only = TRUE ) ){
            #    If package was not able to be loaded then re-install
            install.packages( i , dependencies = TRUE )
            #    Load package after installing
            require( i , character.only = TRUE )
        }
    }
}

package_install(c("ggplot2" , "reshape2" , "corrplot",'ggrepel', 'umap','optparse') )
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(reshape2))
suppressPackageStartupMessages(library(corrplot))
suppressPackageStartupMessages(library(umap))
suppressPackageStartupMessages(library(ggrepel))
suppressPackageStartupMessages(library("optparse"))

option_list = list( 
    make_option("--pro_input",    default=NULL,
                            help="Input file of protein abudence"),
    make_option("--pep_input", default=NULL,
                            help="Input file of peptide abudence"),
    make_option(c("-p", "--prefix"),default=NULL,
                            dest="prefix", help="Prefix"),
    make_option(c("-o", "--outdir"), dest="outdir",default="./", 
                            help="Output dir"),
    make_option(c("-n", "--normalization"), default=NULL, 
                            help="Normalization"),
    make_option(c("-i", "--imputation"), default="F", 
                            help="Normalization"),
    make_option(c("--design_matrix"), 
                            help="Design matrix file")
    
    
)
opt <- parse_args(OptionParser(option_list=option_list))

#read file----------------------------------------------------------------------
##pro data,pep data and log2 transform pro data
pro <- read.csv(opt$pro_input)
colnames(pro) <- gsub('.*\\.\\.','',colnames(pro))
colnames(pro) <- gsub('.raw.*','',colnames(pro))
pro[,-grep('PG',colnames(pro))] <- as.data.frame(apply(pro[,-grep('PG',colnames(pro))],2,as.integer))
log2_pro <- pro
log2_pro[,-grep('PG',colnames(log2_pro))] <- log2(log2_pro[,-grep('PG',colnames(log2_pro))]+1)
if (!is.null(opt$pep_input)) {
    pep <- read.csv(opt$pep_input)
    colnames(pep) <- gsub('.*\\.\\.','',colnames(pep))
    colnames(pep) <- gsub('.raw.*','',colnames(pep))
    pep[,-grep('PG',colnames(pep))] <- as.data.frame(apply(pep[,-grep('PG',colnames(pep))],2,as.integer))
}

#QC-----------------------------------------------------------------------------
qc_dir <- paste0(opt$outdir, '/QC/')
if (!dir.exists(qc_dir)){
    dir.create(qc_dir, recursive = T)
}

##protein QC
if (!is.null(opt$pro_input)) {
    ###protein number
    df_pro_num <- data.frame(sample = colnames(pro)[-grep('PG',colnames(pro))],
                                                pro.num = (nrow(pro)-apply(pro[,-grep('PG',colnames(pro))],2,function(x) sum(is.na(x)))))
    p <- ggplot(data=df_pro_num, aes(x=sample, y=pro.num)) +
        geom_bar(stat="identity", fill="steelblue") +
        theme_classic() +
        labs(fill = "",x="",y='#Protein Groups') +
        scale_x_discrete(guide = guide_axis(angle = 90)) + 
        geom_hline(yintercept=floor(mean(df_pro_num$pro.num)/1000)*1000, linetype="dashed", color = "red")
    if (ncol(pro)>50){
        ggsave(plot = p,filename = paste0(qc_dir,opt$prefix,"_protein_number.pdf"),width = ncol(pro)/10,height = 6)
    }else {
        ggsave(plot = p,filename = paste0(qc_dir,opt$prefix,"_protein_number.pdf"))
    } 

    ###protein distribution
    df_pro_dis <- melt(pro[,-grep('PG',colnames(pro))])
    df_pro_dis <- na.omit(df_pro_dis)
    df_pro_dis$value <- log10(df_pro_dis$value+1)
    p=ggplot(df_pro_dis, aes(x=variable, y=value)) + 
        geom_boxplot(outlier.shape = NA, fill="steelblue")+
        theme_classic()+
        labs(fill = "",x="",y='Log10 Protein Intensity')+
        theme(axis.text.x = element_text( angle=90))+ 
        geom_hline(yintercept=round(median(df_pro_dis$value)), linetype="dashed", color = "red")
    if (ncol(pro)>50){
        ggsave(plot = p,filename = paste0(qc_dir,opt$prefix,"_log10_protein_intensity.pdf"),width = ncol(pro)/10,height =6)
    }else{
        ggsave(plot = p,filename = paste0(qc_dir,opt$prefix,"_log10_protein_intensity.pdf"))
    }
    
    ###correlation for pro
    pro_cor <- pro
    pro_cor[is.na(pro_cor)]=0
    cor_matrix    <-    cor(as.matrix(pro_cor[,-grep('PG',colnames(pro_cor))]))
    df_pro_cor <- melt(cor_matrix)
    df_pro_cor$value <- round(df_pro_cor$value,2)
    if (ncol(cor_matrix) < 20) {
        p=ggplot(data=df_pro_cor,aes(Var1, Var2, fill = value)) + 
            geom_tile(color = "black") +
            theme_classic() +
            scale_fill_gradient(low = 'light yellow', high ='dark green' ) +
            geom_text(aes(label = value)) +
            coord_fixed() +
            scale_x_discrete(guide = guide_axis(angle = 90)) + 
            labs(x='', y='', fill = "Correlation")
        ggsave(filename = paste0(qc_dir,opt$prefix,"_correlation.pdf"),
                     plot = p,width = 6,height = 6)
    } else 
    {
        p <- ggplot(data=df_pro_cor,aes(Var1, Var2, fill = value)) + 
            geom_tile(color = "black")+
            theme_classic()+
            scale_fill_gradient(low = 'light yellow', high ='dark green' ) +
            coord_fixed()+
            scale_x_discrete(guide = guide_axis(angle = 90)) + 
            xlab("") +
            ylab("")+
            labs(fill = "Correlation")
        ggsave(filename = paste0(qc_dir,opt$prefix,"_correlation.pdf"),plot = p,width = ncol(pro)/4,height = ncol(pro)/4)
    }
}

##peptide QC
if (!is.null(opt$pep_input)) {
    ###peptide number---------------------------------------------------------------------
    df <- data.frame(sample = colnames(pep)[-grep('PG',colnames(pep))],
                                pep.num = (nrow(pep)-apply(pep[,-grep('PG',colnames(pep))],2,function(x) sum(is.na(x)))))
    ggplot(data=df, aes(x=sample, y=pep.num)) +
        geom_bar(stat="identity", fill="steelblue") +
        theme_classic() +
        labs(fill="", x="", y='#Peptide Groups') +
        theme(axis.text.x = element_text( angle=90))
    ggsave(plot = p,filename = paste0(qc_dir,opt$prefix,"_peptide_number.pdf"))
    
    ###peptide distribution
    df <- melt(pep[,-grep('PG',colnames(pep))])
    df <- na.omit(df)
    df$value <- log10(df$value+1)
    p <- ggplot(df, aes(x=variable, y=value)) + 
        geom_boxplot(outlier.shape = NA, fill="steelblue") +
        theme_classic() +
        labs(fill = "", x="", y='Log10 Peptide number') +
        theme(axis.text.x = element_text( angle=90))
    ggsave(plot = p,filename = paste0(qc_dir,opt$prefix,"_log10_peptide_intensity.pdf"))
}

#filter sample by the correlation,and protein number----------------------------
##filter sample by the correlation
condition <- unique(gsub('_[1-9]*$','',rownames(cor_matrix)))
median_cor <- data.frame()
for (i in condition) {
    cor_i <- cor_matrix[grep(i,rownames(cor_matrix)),grep(i,colnames(cor_matrix))]
    cor_i_median <- data.frame(apply(cor_i,2,median))
    median_cor <- rbind(median_cor,cor_i_median)
}
cor_filtter <- rownames(median_cor)[median_cor$apply.cor_i..2..median. <= 0.9]

##filter sample by the protein number
pro_number_filtter <- df_pro_num$sample[df_pro_num$pro.num <= mean(df_pro_num$pro.num)-2000]

##sample filter
sample_filter <- union(cor_filtter,pro_number_filtter)
if (length(sample_filter) > 0) {
    pro <- pro[,-which(colnames(pro) %in% sample_filter)]
    write.csv(pro, file = paste0(opt$outdir,"/",opt$prefix,"pro_intensity_fillter.csv"))
}

#normalization------------------------------------------------------------------
if (!is.null(opt$n)){
    pro[,-grep('PG',colnames(pro))] <- apply(pro[,-grep('PG',colnames(pro))],2,
                                                                                function(x) x*10^(round(median(df_pro_dis$value)))/(median(na.omit(x))))
    write.csv(pro, file=paste0(opt$outdir,"/",opt$prefix,"pro_median_nor.csv"))
}

#proteomics data cluster--------------------------------------------------------
cluster_dir <- paste0(opt$outdir, '/cluster_plot/')
if (!dir.exists(cluster_dir)){
    dir.create(cluster_dir, recursive = T)
}

##cluster data(na=0)
cluster_data <- pro[,-grep('PG',colnames(pro))]
cluster_data[is.na(cluster_data)]=0
cluster_data <- cluster_data[which(rowSums(cluster_data)>0),]
log2_cluster_data <- log2(cluster_data+1)

##PCA and plot
pca_data <- t(log2_cluster_data)
pca <- prcomp(pca_data, center = TRUE, scale. = TRUE) #pca,remember if you use the sample to do the pca,you need to transpose
pca_df <- as.data.frame(pca$x)
pca_df$Condition <- gsub('_[1-9]*$','',rownames(pca_df))
percentage <- round(summary(pca)$importance[2,]*100, digits = 2)
allcolour <- c("#DC143C","#0000FF","#20B2AA","#FFA500","#9370DB","#1E90FF",
                        "#7CFC00","#FFFF00","#808000","#FF00FF","#FA8072","#7B68EE",
                        "#9400D3","#800080","#A0522D","#D2B48C","#D2691E","#87CEEB",
                        "#40E0D0","#5F9EA0","#FF1493","#0000CD","#008B8B","#FFE4B5",
                        "#8A2BE2","#228B22","#E9967A","#4682B4","#32CD32","#F0E68C",
                        "#FFFFE0","#EE82EE","#FF6347","#6A5ACD",
                        "#9932CC","#8B008B","#8B4513","#DEB887")
p <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Condition)) +
    geom_point(size=4) +
    xlab(paste0("PC1","(",percentage[1],"%)")) +
    ylab(paste0("PC2","(",percentage[2],"%)")) +
    scale_color_manual(values = allcolour) +
    theme_classic() +
    stat_ellipse(level=0.95)
ggsave(plot = p,filename = paste0(cluster_dir,opt$prefix,"_PCA_circle.pdf"),height = 7,width = 9)

p <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Condition)) +
    geom_point(size=4) +
    xlab(paste0("PC1","(",percentage[1],"%)")) +
    ylab(paste0("PC2","(",percentage[2],"%)")) +
    scale_color_manual(values = allcolour) +
    theme_classic()
ggsave(plot = p,filename = paste0(cluster_dir,opt$prefix,"_PCA.pdf"),height = 7,width = 9)


## hc
dist_mat <- dist(t(log2_cluster_data)) #
hc_cluster <- hclust(dist_mat,method = "complete")
samplesname <- colnames(log2_cluster_data)
pdf(file=paste0(cluster_dir, opt$prefix,"_hc_cluster_log2.pdf"))
plot(hc_cluster,cex=0.8,col="dark red",labels = samplesname,main="HC Cluster")
dev.off()

## mean to one
data_in1 <- data.frame(row.names = rownames(log2_cluster_data))
for (i in unique(gsub("_[1-9]*$",'',colnames(log2_cluster_data)))) {
    tmp <- log2_cluster_data[,grep(i, colnames(log2_cluster_data)),]
    tmp_i <- data.frame(rowMeans(tmp),row.names = rownames(log2_cluster_data))
    colnames(tmp_i) <-i
    data_in1 <- cbind(data_in1,tmp_i)
}

dist_mat <- dist(t(data_in1)) #
hc_cluster <- hclust(dist_mat,method = "complete")
samplesname <- colnames(data_in1)
pdf(file = paste0(cluster_dir,opt$prefix,"_hc_cluster_log2_mean.pdf"))
plot(hc_cluster,cex=0.8,col="dark red",labels = samplesname,main="HC Cluster")
dev.off()

## umap
if (length(unique(gsub('_[1-9]*$','',colnames(log2_cluster_data)))) > 6) {
    umap_data <- t(log2_cluster_data)
    set.seed(100)
    umap_out <- umap(umap_data)
    umap_df <- as.data.frame(umap_out$layout) 
    colnames(umap_df) <-c("UMAP1","UMAP2")
    umap_df$Condition <- gsub('_[1-9]*$','', rownames(umap_df))
    
    p <- ggplot(umap_df) +
        geom_point(aes(x=UMAP1, y=UMAP2, color=Condition),size=4) +
        scale_color_manual(values = allcolour) +
        theme_classic()
    ggsave(plot = p,filename = paste0(cluster_dir,opt$prefix,"umap.pdf"),height = 7,width = 9)
}

# DE analysis--------------------------------------------------------------------
DE_dir <- paste0(opt$outdir, '/DE_analysis/')
if (!dir.exists(DE_dir)){
    dir.create(DE_dir, recursive = T)
}

## read files
pro <- pro[which(rowSums(pro[,-grep('PG',colnames(pro))])>0),]
design_matrix <- read.csv(opt$design_matrix)

## Differential Expression parameters 
fdr_cutoff <- 0.05
lfc_cutoff <- 0.585
enrich_pvalue <- 0.05
gsea_fdr_cutoff <- 0.05

## ttest
condition <- unique(design_matrix$condition)
for (i in condition) {
    data_i <- pro[,grep(i,colnames(pro))]
    data_control <- pro[,grep(unique(design_matrix$control[which(design_matrix$condition == i)]),colnames(pro))]
    data <- cbind(data_i,data_control)
    data[is.na(data)]=0
    rownames(data) <- pro$PG.ProteinGroups
    rm <- apply(data, 1, function(x){
        sum(x == 0) > ncol(data)/2
    })
    df <- data[!rm,]
    df <- df[apply(df,1, var) != 0, ]
    df <- df[apply(df[,grep(i,colnames(df))],1, var) != 0, ]
    df <- df[apply(df[,grep(unique(design_matrix$control[which(design_matrix$condition == i)]),colnames(df))],1, var) != 0, ]
    pvalue <- apply(df, 1, function(x){
        a = factor(c(rep('treat',ncol(data_i)),
                                rep("control",ncol(data_control))),
                            levels = c('treat',"control"))
        fvalue = var.test(x~a)
        if (!is.na(fvalue$p.value)){ 
            if (fvalue$p.value > 0.05){
                t.test(x~a, var.equal = T)
            }else{
                t.test(x~a, var.equal = F)
            }}
    })

    result_ttest <- data.frame(ID=names(pvalue), 
                                                    Pvalue = as.numeric(unlist(lapply(pvalue,function(x) x$p.value))),
                                                    log2FC = log2(as.numeric(unlist(lapply(pvalue,function(x) x$estimate[1]/(x$estimate[2]+1))))))
    
    result_ttest$adj.Pvalue <- p.adjust(result_ttest$Pvalue, method = 'BH', n = length(result_ttest$Pvalue))
    result_ttest <- merge(df,result_ttest,by.x =0,by.y =1,all=F)
    result_ttest <- merge(pro[,grep("PG",colnames(pro))],result_ttest,by=1,all=F)
    result_ttest <- result_ttest[order(result_ttest$log2FC,decreasing = T),]
    
    write.csv(result_ttest,file = paste0(DE_dir,i,'_',unique(design_matrix$control[which(design_matrix$condition==i)]),'_ttest.csv'),row.names = F)
    result_ttest <- na.omit(result_ttest)
    options(ggrepel.max.overlaps=Inf)
    volcano_plot <- result_ttest
    volcano_plot$Group <- "Others"
    volcano_plot$Group[which(volcano_plot$log2FC >= lfc_cutoff)] <-"UP"
    volcano_plot$Group[which(volcano_plot$log2FC <= -lfc_cutoff)] <-"DOWN"
    volcano_plot$Group[which(volcano_plot$adj.Pvalue >= fdr_cutoff)]<- "Others"

    up_gene_5 <- volcano_plot[which(volcano_plot$Group=="UP"),]
    up_gene_5 <- up_gene_5[order(up_gene_5$log2FC,decreasing = T)[1:5],]

    down_gene_5 <- volcano_plot[which(volcano_plot$Group=="DOWN"),]
    down_gene_5 <- down_gene_5[order(down_gene_5$log2FC,decreasing = F)[1:5],]

    top5_gene <- rbind(up_gene_5,down_gene_5)
    top5_gene <- top5_gene[!duplicated(top5_gene$PG.Genes),]

    p <- ggplot(volcano_plot, aes(x = log2FC, y = -log10(adj.Pvalue))) +
        geom_point(aes(color = Group)) +
        scale_color_manual(values = c("blue", "grey","red")) +
        theme_bw(base_size = 12) + theme(legend.position = "bottom") +
        geom_label_repel(
            data = subset(top5_gene),
            aes(label = PG.Genes),
            size = 5,
            box.padding = unit(0.35, "lines"),
            point.padding = unit(0.3, "lines")) +
        geom_hline(yintercept=-log10(fdr_cutoff), linetype="dashed") + 
        geom_vline(xintercept=lfc_cutoff, linetype="dashed") + 
        geom_vline(xintercept=-lfc_cutoff, linetype="dashed") +
        theme_classic()
    
    ggsave(file = paste0(DE_dir,i,"_",opt$control,"_top10_fdr0.05_fc1.5_vocal.pdf"),plot = p,width = 8,height = 8)
}










