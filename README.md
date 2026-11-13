# MATLAB Scripts – TDK 2026

This repository contains the MATLAB scripts used for data processing and analysis in my TDK, *Brain Temperature Changes During Epileptic Seizures in Freely Moving Mice*.

The measurements were performed on two animals (TE2 and TE9). The scripts are organized below according to the different parts of the analysis.

## Temperature analysis

- `temperature_csv_to_mat.m` – Converts temperature data from CSV to MAT format.
- `temperature_sync.m` – Synchronizes temperature recordings with the electrophysiological data.
- `temperature_delta_A.m` – Calculates temperature changes during optogenetic stimulation.
- `temperature_delta_statistics.m`, `temperature_delta_final.m`, `temperature_mean_response.m` – Calculate summary statistics and generate temperature plots.

## LFP and seizure analysis

- `lfp_preprocessing.m` – Prepares the recorded LFP signals for analysis.
- `temperature_lfp_all.m` – Plots LFP and temperature recordings together.
- `seizure_analysis.m` – Generates a spectrogram and calculates LFP RMS values for a selected recording.

## Local heating experiments

- `heating_temperature.m` – Calculates temperature changes during individual heating experiments.
- `heating_current_vs_temperature.m` – Summarizes the temperature changes at different heating currents.
- `heating_lfp_alignment.m` – Aligns the heating measurements with the electrophysiological recordings.
- `heating_lfp_rms_batch.m` – Calculates high-frequency LFP RMS ratios during heating.
- `heating_lfp_rms_summary.m` – Summarizes and plots the RMS results.

## Electrode impedance

- `impedance_analysis.m` – Analyzes electrode impedance measurements over time.

## Notes

The scripts use file or folder selection where needed. The corresponding experimental data files are not included in this repository.
