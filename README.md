# README

# Quick-start
Executing [`run.sh`](src/run.sh) runs the pipeline outlind below. Briefly, it
1. Retrieves the required pre-built singularity image 
2. Defines input/output parameters
3. Executes the processing script [`processing.R`](src/processing.R) within a singularity container

# In greater detail
## Retrieve singularity image
[`run.sh`](src/run.sh) first retrieves the singularity image (currently stored on onedrive for
direct download using `wget`) if it does not exist.
```bash
img='r-4.0'
id='77DD71E598E5B51B'
auth='AJdCAAZQQrCo9cc'
if [ ! -f ${img}.sif ]; then
    wget -O ${img}.sif \
        "https://onedrive.live.com/download?cid=${id}&resid=${id}%2124983&authkey=${auth}"
fi
```

The image was built from [`r-4.0.singularity`](src/r-4.0.singularity) using the sylabs remote 
builder, i.e.:

```bash
singularity build --remote src/${img}.sif src/${img}.singularity
```

## Running the processing R script
After ensuring the singularity image is available, [`run.sh`](src/run.sh) defines input/output
parameters and executes [`processing.R`](src/processing.R) within the container, generating
plots or tables within the defined output directories.

```bash
pro_input='input/spe_Report_Proteins.csv' #csv of the protein groups quntification generated by SN
project_name='test' #the name of this project
outdir='./output' #output dir
design_matrix='input/design_matrix.csv' #csv file of design matrix for comparison
r_script='processing.R'

# unused / NYI:
# pep_input='' #the csv file of the peptide intensity from the SN
# normalization='' # 'T' or 'F'

module load singularity

singularity run -H $PWD:/home src/${img}.sif \
    Rscript src/${r_script} \
    --pro_input ${pro_input} \
    -p ${project_name} \
    -o ${outdir} \
    --design_matrix ${design_matrix}
```

## TODO


