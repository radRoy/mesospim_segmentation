--- *exhaustive overhaul of whole segmentation pipeline in progress* ---

# mesoSPIM Segmentation Pipeline

The next TODO item is to use [snakemake] to chain together my existing mesospim segmentation workflow ([file_handling], [WaltherFiji], [imageProcessTif], [cloud], [bash_scripts]) into one functioning pipeline. First, I integrate these separate GitHub repositories (repos) into this [radRoy]/[mesospim_segmentation] as `git submodule`s. When the `snakemake` pipeline will have been tested to work, I want to merge the separate codebases by migrating their functionalities into this repo.

## Ordered Pipeline Workflow

### Overview & Data Flow
```text
[MesoSPIM Raw Acquisition (.h5/.xml)]
             │
             ▼ (BigStitcher Resave)
       [Raw TIFF Stacks]
             │
             ▼ (change_voxel_size_interactive_loop.ijm)
    [Calibrated TIFF Stacks]
             │
             ▼ (scale_tifs.ijm)
      [Scaled TIFF Stacks]
             │
             ▼ (croppingCoordinateCalculation.py / crop_csv.ijm / crop_tifs-Static-dataset*.ijm)
      [Cropped TIFF Stacks]
        ┌─────┴──────────────────────────┐
        │                                │
        ▼ (label_tifs_heart-dataset*.ijm / labelTifs.ijm / eye curation macros)
  [Binary Mask (uint8)]                  │
        │                                ▼ (concatenateChannels.py)
        │                      [Multi-Channel Stack (C,Z,Y,X uint16)]
        │                                │
        └────────────────┬───────────────┘
                         │
                         ▼ (writeH5.py)
               [HDF5 Container File (.h5)]
               ├── /raw   (C, Z, Y, X)
               └── /label (Z, Y, X)
                         │
                         ▼ (calculate_valid_patchStride.py & yamlHandling.py)
               [Cluster Training: train3dunet]
                         │
                         ▼ (predict3dunet)
               [Prediction Probability Stacks (.h5)]
                         │
        ┌────────────────┴────────────────────────┐
        │                                         │
        ▼ (IoU_batch_processor.py)                ▼ (h5_predict3dunet_to_Segmentation.py / probability_thresholding.ijm)
[Evaluation & IoU Scores]                 [BDV XML/H5 & Thresholded Binary Segmentations]
```

---

### Pipeline Stages

#### Stage 1: Ingestion, Rescaling & Metadata Correction
1. **BigStitcher Resave** (Fiji plugin)
   - **Input:** mesoSPIM raw acquisition (`.h5` / `.xml`).
   - **Output:** Single-channel raw TIFF stacks (stitched or unstitched).
2. **`WaltherFiji/Voxel size correction Snippets/change_voxel_size_interactive_loop.ijm`**
   - **Input:** Raw TIFF stacks with uncalibrated metadata.
   - **Output:** Calibrated TIFFs with defined isotropic/anisotropic voxel sizes ($z, y, x$ in µm).
3. **`WaltherFiji/Scaling/scale_tifs.ijm`** (and dataset-specific variants `scale_tifs-dataset*.ijm`)
   - **Input:** Full-resolution raw TIFF stacks.
   - **Output:** Bicubic downscaled single-channel TIFF stacks (`scaled0.25`, `scaled0.5`).

#### Stage 2: Specimen Bounding-Box Cropping
4. **`imageProcessTif/croppingCoordinateCalculation.py`**
   - **Input:** Metadata spreadsheet with specimen coordinates (`.xlsx`).
   - **Output:** Normalized, boundary-checked 3D bounding box coordinates (`*-filled.xlsx`).
5. **`WaltherFiji/Cropping/crop_csv.ijm`** / **`crop_tifs-Static-dataset*.ijm`**
   - **Input:** Scaled single-channel TIFFs + bounding box coordinates (`.csv` / `.xlsx`).
   - **Output:** Standardized, cropped specimen single-channel TIFF stacks.

#### Stage 3: Ground Truth Labeling & Mask Generation
6. **`WaltherFiji/Labelling/label_tifs_heart-dataset*.ijm`** / **`labelTifs.ijm`**
   - **Input:** Cropped fluorescence / autofluorescence TIFF stacks.
   - **Output:** 2D/3D thresholded binary masks (`uint8`, foreground = 255, background = 0).
7. **`WaltherFiji/Labelling/label_tifs_eyes-dataset10-macro1` to `macro5` series**
   - **Order:**
     - `macro1-binary_mask_to_overlay.ijm` $\rightarrow$ Converts binary masks to editable ROI overlays.
     - `macro2-rename_slices_after_manual_correction.ijm` $\rightarrow$ Synchronizes manual slice edits.
     - `macro3-transfer_overlays_to_substack_as_stack.ijm` $\rightarrow$ Assembles edited overlays into substacks.
     - `macro4-substack_to_sliced.ijm` $\rightarrow$ Slices substacks into individual frames.
     - `macro5-overlay_to_mask.ijm` $\rightarrow$ Converts curated overlays back into full binary masks.
   - **Input:** Initial segmentation masks.
   - **Output:** Manually curated, error-free binary masks.
8. **`WaltherFiji/Labelling/fill_holes_2D_in_binary_mask_stack_dataset11.c.ijm`** / **`fill_holes_2D_and3D.groovy`**
   - **Input:** Binary segmentation masks with internal voids.
   - **Output:** Morphologically filled binary masks.
9. **`imageProcessTif/union_of_two_binary_mask_stacks.py`**
   - **Input:** Multiple individual binary mask stacks (e.g., separate organ structures).
   - **Output:** Merged composite binary ground truth mask stack.

#### Stage 4: Multi-Channel Concatenation & HDF5 Packaging
10. **`imageProcessTif/convertTif16bitTo8bit.py`** / **`convertTifList16bitTo8bit.py`** *(optional)*
    - **Input:** 16-bit TIFF stacks.
    - **Output:** 8-bit scaled TIFF stacks.
11. **`imageProcessTif/concatenateChannels.py`**
    - **Input:** Cropped single-channel autofluorescence TIFF stacks (`Ch405nm`, `Ch488nm`, `Ch561nm`).
    - **Output:** Multi-channel stacked TIFF formatted as `(C, Z, Y, X)` in `uint16`.
12. **`imageProcessTif/tifFormatting.py`** / **`readTifFormatTest.py`**
    - **Input:** Concatenated TIFF arrays.
    - **Output:** Validated dimension ordering `(C, Z, Y, X)` and data types.
13. **`imageProcessTif/writeH5.py`** (supported by **`readH5.py`**)
    - **Input:**
      - Concatenated raw TIFFs $\rightarrow$ written to `/raw` (`(C, Z, Y, X)`).
      - Binary ground truth masks $\rightarrow$ written to `/label` (`(Z, Y, X)`).
    - **Output:** Final HDF5 container (`.h5`) for 3D U-Net training.

#### Stage 5: Cloud Cluster Training & HPC Orchestration
14. **`cloud/calculate_valid_patchStride.py`** & **`cloud/calculate_LR_steps.py`**
    - **Input:** Dataset volumetric dimensions and cluster VRAM constraints.
    - **Output:** Valid isotropic/anisotropic `patch_shape` and `stride_shape` configurations ($2^3$ multiples).
15. **`cloud/yamlHandling.py`**
    - **Input:** Base template YAML (`3dunet.yml` / `train_config.yml`).
    - **Output:** Session-specific configuration file with resolved absolute paths and hyperparameters.
16. **`cloud/start_train3dunet.py`** (invoking `train3dunet --config <train_config.yml>`)
    - **Input:** Generated YAML configuration + prepared HDF5 datasets on cluster scratch storage.
    - **Output:** Model checkpoint directory (`last_checkpoint.pytorch`, `best_checkpoint.pytorch`).
17. **`cloud/nvidia-smi-separate_sessions.py`** / **`cloud/VRAM analysis.R`**
    - **Input:** Background `nvidia-smi.log` metrics during training.
    - **Output:** VRAM utilization telemetry and GPU profiling logs.

#### Stage 6: Model Inference & Prediction Post-Processing
18. **`predict3dunet --config <test_config.yml>`**
    - **Input:** Trained checkpoint + test volume HDF5 container.
    - **Output:** Float32 probability map prediction HDF5 container (`.h5`).
19. **`imageProcessTif/h5_predict3dunet_to_Segmentation.py`**
    - **Input:** Prediction `.h5` float32 probability volume.
    - **Output:** BigDataViewer (BDV) XML/H5 format via `npy2bdv` or multi-channel TIFF.
20. **`WaltherFiji/Labelling/probability_thresholding_(Label_prediction).ijm`** / **`predict3dunet_helper-binary_to_overlay.ijm`**
    - **Input:** Prediction probability volumes.
    - **Output:** Binarized predicted segmentation masks and ROI overlays.

#### Stage 7: Evaluation & IoU Benchmarking
21. **`imageProcessTif/IoU_batch_processor.py`** (validated via **`yaml_tester.py`**)
    - **Input:** Ground truth binary masks (`/label`) + model predictions across thresholds [0.1–1.0].
    - **Output:** Intersection over Union (IoU / Jaccard Index) sweep metrics, highscore identification, and serialized YAML summary reports.
22. **`WaltherFiji/Analysis/IoU_prep_Otsu_threshold_series.ijm`**
    - **Input:** Prediction image series.
    - **Output:** Fiji-based overlap and threshold evaluation stacks.

#### Shared Core Utilities
- **`file_handling/fileHandling.py`** & **`file_handling/File_Handling.ijm`**: Core path resolution, directory generation, filename filtering, and batch I/O used across all Python and ImageJ scripts.
- **`mesospim_segmentation/`**: The target monorepo root designed to unify the sub-packages into a cohesive pipeline managed by `uv`.

---

## Reference Text Passages

### 1. End-to-End Pipeline Scope (`imageProcessTif/AGENT_ORIENTATION.md`, lines 6–9)
> 1. **Microscopy & Preprocessing:** Light-sheet (mesoSPIM) raw data ingestion, cropping, channel concatenation, format conversions (TIF / HDF5 / BigStitcher), metadata handling, and PyImageJ integrations.  
> 2. **Segmentation & Training:** 3D U-Net / deep learning segmentation training workflows dispatched via **SLURM** on an HPC cluster.  
> 3. **Model Evaluation & Metrics:** Intersection over Union (IoU), threshold sweeps, segmentation quality assessment, and validation pipelines.

### 2. Sequential Data Processing Flowchart (`imageProcessTif/README.md`, lines 42–70)
> ```text
> [MesoSPIM Output (.h5/.xml)]
>              │
>              ▼ (BigStitcher Resave)
>        [Raw TIFFs]
>              │
>              ▼ (scaleTifs-dataset.ijm)
>      [Scaled TIFFs]
>              │
>              ▼ (croppingCoordinateCalculation.py / cropTifs.ijm)
>      [Cropped TIFFs]
>        ┌─────┴──────────────────────────┐
>        │                                │
>        ▼ (labelTifs.ijm)                ▼ (concatenateChannels.py)
>  [Binary Mask (uint8)]        [Multi-Channel Stack (C,Z,Y,X uint16)]
>        │                                │
>        └────────────────┬───────────────┘
>                         │
>                         ▼ (writeH5.py)
>               [HDF5 Container File]
>               ├── /raw   (C, Z, Y, X)
>               └── /label (Z, Y, X)
>                         │
>                         ▼
>           [pytorch-3dunet Training]
>                         │
>                         ▼ (IoU_batch_processor.py)
>               [Evaluation / IoU Scores]
> ```

### 3. HPC Cluster Schematic Workflow (`cloud/README.md`, lines 209–218 & `cloud/README-commands_only.md`)
> - get data from microscope  
> - input data formatting (to HDF5: autofluorescence: CZYX (uint8/uint16 works), label: ZYX)  
> - transfer data with globus  
> - adapt model parameters (paths, shapes, checkpoint folder, config yaml)  
> - adapt train_config.yml; make a copy & rename according to settings  
> - git sync the files between PC and cluster  
> - run the shell commands (`train3dunet`, `predict3dunet`)

### 4. Fiji Image Processing & Annotation Steps (`WaltherFiji/README.md`)
> - **Scaling:** `scale_tifs.ijm` to bicubic downscale single/multi-channel stacks for memory efficiency.
> - **Cropping:** `crop_csv.ijm` taking coordinate inputs to extract specimen bounding boxes.
> - **Labelling:** Heart and eye annotation macros (`label_tifs_heart-dataset*.ijm`, eye curation macros 1 to 5) for ground truth binary mask generation and slice-by-slice manual curation.
> - **Analysis & Evaluation:** `IoU_prep_Otsu_threshold_series.ijm` and `probability_thresholding_(Label_prediction).ijm` for thresholding prediction stacks and evaluating segmentation quality against ground truth.


[radRoy]: https://github.com/radRoy
[mesospim_segmentation]: https://github.com/radRoy/mesospim_segmentation.git
[file_handling]: https://github.com/radRoy/file_handling.git
[WaltherFiji]: https://github.com/radRoy/WaltherFiji.git
[imageProcessTif]: https://github.com/radRoy/imageProcessTif.git
[cloud]: https://github.com/radRoy/cloud.git
[bash_scripts]: https://github.com/radRoy/bash_scripts.git

[snakemake]: https://snakemake.readthedocs.io/
