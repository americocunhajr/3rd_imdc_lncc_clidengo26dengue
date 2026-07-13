## LNCC-CLiDENGO26-Dengue

<div style="display: flex; align-items: center; flex-wrap: wrap;">
  <div style="flex: 0 0 auto; margin-right: 20px;">
    <img src="logo/logo-CLiDENGO.png" alt="LNCC-CLiDENGO" width="20%">
  </div>
  <div style="flex: 1 1 auto; min-width: 250px;">
    <strong>CLiDENGO</strong> is a forecasting model for dengue dynamics through a mechanistic, stochastic climate-modulated β-logistic growth model for weekly dengue cases at the state (UF) level. It couples a flexible epidemic growth core with a climate response so that periods of favorable weather (e.g., warm, humid, rainy) accelerate epidemic growth in a data-driven way.
  </div>
</div>

#### Repository structure:
```
3rd_imdc_lncc_clidengo26dengue/
│
|── Data: surveillance and climate data aggregated at the state level
│
|── Dengue_Validation1_2022–2023-Season: model output files for validation challenge 1
|── Dengue_Validation2_2023–2024-Season: model output files for validation challenge 2
|── Dengue_Validation3_2024–2025-Season: model output files for validation challenge 3
|── Dengue_Validation4_2025–2026-Season: model output files for validation challenge 4
│
|── logo: D-FENSE team logo files
```

#### Authors:
* Prof. Americo Cunha Jr (LNCC/UERJ, Brazil)
* Prof. Emanuelle Arantes Paixão (LNCC, Brazil)
* Prof. Christian Soize (Université Gustave Eiffel, France)

#### Data and Variables: 
We use surveillance (weekly probable cases) together with climate covariates - temperature (min/mean/max), precipitation (min/mean/max), and relative humidity (min/mean/max) - aggregated at the UF level. Data are arranged as seasons of 52 weeks, from EW 41 of year Y to EW 40 of Y+1. Climate series are min–max normalized on the training set and lightly denoised to form a baseline seasonal signal; case series are also denoised for QoI preparation while keeping values non-negative and integer when reported. Training uses multiple past seasons (e.g., 2010–2011 to 2020–2021); the next season (e.g., 2022–2023) is held out for validation. These inputs come from the 'Data' repository.

#### Model Structure: 
CLiDENGO forecasts weekly dengue incidence by integrating a β-logistic growth ODE whose effective growth rate can be modulated by climate (temperature, precipitation, relative humidity). The model is trained per state (UF) and produces median and 50/80/90/95% prediction intervals.

- State variable: The model tracks the cumulative number of probable cases per week, denoted here as C(t). The incidence (new cases per week) is computed as the model’s rate of change, reported as dC(t).
- Growth law: The epidemic growth belongs to the beta-logistic family. In words:
	*	the growth rate increases with the current epidemic size following an “early growth” exponent q;
	*	growth slows down as the curve approaches a final size K, with asymmetry controlled by alpha and late-time sharpness by p;
	*	a baseline growth scale r0 multiplies the whole response.
- Climate modulation: The baseline growth r0 can be modulated by climate using smooth suitability factors (Brière-type) for temperature, precipitation, and relative humidity. Each factor maps the normalized climate series to a value in [0,1] using biologically plausible lower/upper thresholds (e.g., temperature roughly in the 18–32 °C window). The effective growth is r0 multiplied by one or more of these suitability factors (temperature only, temperature × precipitation, or temperature × precipitation × humidity; the switch is in the code).
- Climate preprocessing: Raw climate series (weekly medians with min/max envelopes) are min-max normalized over the training data range, denoised with a short symmetric filter and/or SVD-based smoothing, and can be time-shifted by integer lags lag_T, lag_P, lag_H (negative values mean climate leads the cases by that many weeks).
- Initial condition: The initial cumulative value C0 for each season is taken from the first week (EW 41) of that season. For stochastic runs, C0 is sampled from the pool of training-season initial values.
-	Stochastic parameters: Around the calibrated means, the model draws random parameters per Monte Carlo realization using simple distributions controlled by coefficients of variation:
	*	r0 ~ Gamma;
	*	p ~ shifted-Gamma (bounded below by 1);
	*	K, q, alpha ~ Uniform on symmetric intervals around their means;
	*	C0 ~ empirical draw from the training seasons.
-	Integration: For each realization, the ODE is integrated weekly across the 52-week window with ode45. The code returns an ensemble of C(t) and dC(t) to compute medians and prediction intervals.

#### Model Training: 
Each season is 52 weeks from EW 41 of year Y to EW 40 of Y+1 (consistent with the Sprint evaluation windows). Validation is one season ahead. For instance, for validation challenge 1, training uses seasons 2010–2011 to 2020–2021, and validation uses the 2022-2023 season. Prior (probabilistic) model parameters are identified by least squares using historical seasons as observations (each season spans EW 41 of year Y to EW 40 of year Y+1). Fitting is performed per UF, yielding a climate-response and logistic growth structure tailored to each state.

#### Forecasting: 
With the identified parameters and lags, we re-run the simulator with a larger ensemble (thousands of realizations) and integrate the ODE 52 weeks into the future (EW 41 → EW 40 of the next year). For each realization, we obtain weekly incidence and cumulative trajectories driven by the climate modulators. Reported weekly cases are kept non-negative and rounded to integers.

#### Predictive Uncertainty:
From the Monte Carlo simulation, done with 1024 realizations by sampling from the learned parameter priors (and perturbing climate inputs), we compute the mean and central prediction intervals at 50%, 80%, 90%, 95% using prctile.m. Lower bounds use the 25%, 10%, 5%, and 2.5% percentiles; upper bounds use the 75%, 90%, 95%, and 97.5% percentiles, respectively. 

#### Model Output:
- median prediction: mean value
- 50% prediction interval: from 25% percentile to 75% percentile
- 80% prediction interval: from 10% percentile to 90% percentile
- 90% prediction interval: from 5% percentile to 95% percentile
- 95% prediction interval: from 2.5% percentile to 97.5% percentile

#### Libraries and Dependencies (MATLAB):
- fmincon.m (Optimization Toolbox)
- gamrnd.m (Statistics and Machine Learning Toolbox)
- prctile.m (Statistics and Machine Learning Toolbox)
