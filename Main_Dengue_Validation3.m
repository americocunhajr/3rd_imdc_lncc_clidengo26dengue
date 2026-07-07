% -----------------------------------------------------------------
%  Main_Dengue_Validation3.m
% -----------------------------------------------------------------
%  This program runs a predictive model for Dengue outbreaks.
% -----------------------------------------------------------------
%  Programmers: Americo Cunha Jr
%               americo.cunhajr@gmail.com
%               
%               Christian Soize
%               christian.soize@univ-eiffel.fr
%               
%  Initially Programmed: Jul 06, 2026
%           Last Update: Jul 06, 2026
% -----------------------------------------------------------------


clc; clear; close all

% program execution start time
% -----------------------------------------------------------
timeStart = tic();
% -----------------------------------------------------------


% Program header
% -----------------------------------------------------------
disp(' ------------------------------------------------------ ')
disp(' IMDC 2026                                              ')
disp(' Dengue - Validation Test 3                             ')
disp('                                                        ')
disp(' by                                                     ')
disp(' Americo Cunha Jr                                       ')
disp(' Christian Soize                                        ')
disp(' ------------------------------------------------------ ')
% -----------------------------------------------------------


% simulation information
% -----------------------------------------------------------
case_name = 'IMDC2026_Dengue_Validation3';

disp(' '); 
disp([' Case Name: ',num2str(case_name)]);
disp(' ');

% random number generator (fix the seed for reproducibility)
rng_stream = RandStream('mt19937ar','Seed',30081984);
RandStream.setGlobalStream(rng_stream);

% number of Monte Carlo realizations
nReal = 128;
% -----------------------------------------------------------

% Define range of dates
% -----------------------------------------------------------

% number of epidemiological weeks in a year
nEW = 52;

% number of years for training 
% --- seasons 2010-2011 until 2022-2023 ---
nYearsTrain = 13;

% define validation range endpoints
% --- season 2024-2025 ---
startDate = datetime("2024-10-06");    % 41th EW of 2024
endDate   = datetime("2025-09-28");    % 40th EW of 2025

% build daily vector
dates_valid = (startDate:caldays(7):endDate)';

% set display format to YYYY-MM-DD
dates_valid.Format = "yyyy-MM-dd";
% -----------------------------------------------------------

% Define the output filenames for the current state
% -----------------------------------------------------------
 DirNameCSV_inp = 'Data';
FileNameCSV_inp = 'IMDC2026_AggregatedData-Dengue_';
 DirNameCSV_out = 'Dengue_Validation3_2024–2025-Season';
FileNameCSV_out = 'IMDC2026_Dengue_Validation3_';
% -----------------------------------------------------------

% List of the federation units (ufs) / Brazilian states
% -----------------------------------------------------------
FederativeUnitsNames = {
    'AC',  % Acre
    'AL',  % Alagoas
    'AP',  % Amapa
    'AM',  % Amazonas
    'BA',  % Bahia
    'CE',  % Ceara
    'DF',  % Distrito Federal
    'ES',  % Espirito Santo
    'GO',  % Goias
    'MA',  % Maranhao
    'MT',  % Mato Grosso
    'MS',  % Mato Grosso do Sul
    'MG',  % Minas Gerais
    'PA',  % Para
    'PB',  % Paraiba
    'PR',  % Parana
    'PE',  % Pernambuco
    'PI',  % Piaui
    'RJ',  % Rio de Janeiro
    'RN',  % Rio Grande do Norte
    'RS',  % Rio Grande do Sul
    'RO',  % Rondonia
    'RR',  % Roraima
    'SC',  % Santa Catarina
    'SP',  % Sao Paulo
    'SE',  % Sergipe
    'TO'   % Tocantins
};

% Number of federation units (ufs) / Brazilian states
Nufs = length(FederativeUnitsNames);
% -----------------------------------------------------------


% Loop over each federation unit to make predictions
% -----------------------------------------------------------
for j = 1:Nufs

    % Extract the current state 'uf'
    current_uf = FederativeUnitsNames{j};

    % Display processing message
    disp(['Computing predictions for ', current_uf, ' ...']);

    % =================
    % Process the data
    % =================

    % read .csv data file with the raw data
    DataRaw = readtable([DirNameCSV_inp,'/',FileNameCSV_inp,current_uf]);
    
    % index for the first and last EWs of training
    Train_Start = 41;
    Train_End   = Train_Start + nYearsTrain*nEW - 1;
    
    % index for the first and last EWs of validation 
    Valid_Start = Train_End + 1;
    Valid_End   = Valid_Start + nEW - 1;
    
    % define the training dataset
    DataTrain = DataRaw(Train_Start:Train_End,:);
    
    % define the validation dataset
    DataValid = DataRaw(Valid_Start:Valid_End,:);

    % define climate and survailance time-series
    DataTrain_T         = DataTrain.temp_med;
    DataTrain_P         = DataTrain.precip_med;
    DataTrain_H         = DataTrain.rel_humid_med;
    DataTrain_incidence = DataTrain.cases;
    
    % filter coefficients (half-window m = 2 here)
    FilterCoeffs = [0.05; 0.10; 0.7; 0.10; 0.05];
    
    % baseline (filtered) surveillance  and climate time-series
    % -- this filter is different than the one used for visualization --
     T_baseline = ApplyFilter(DataTrain_T ,FilterCoeffs);
     P_baseline = ApplyFilter(DataTrain_P ,FilterCoeffs);
     H_baseline = ApplyFilter(DataTrain_H ,FilterCoeffs);
    
    % Remove potentially negative values
    % --- filtering process may introduce negative values
     T_baseline = RemoveNonNegativeValues(T_baseline);
     P_baseline = RemoveNonNegativeValues(P_baseline);
     H_baseline = RemoveNonNegativeValues(H_baseline);
    
    % define QoIs data for calibration (nEW x nYears)
    DataTrain_incidence = reshape(DataTrain_incidence,nEW,[]);
    DataTrain_prevalence = cumsum(DataTrain_incidence);

    % define QoIs data for validation (nEW x 1)
    DataValid_incidence  = DataValid.cases;
    DataValid_prevalence = cumsum(DataValid_incidence);

    % ================================
    % define the nominal model struct
    % ================================

    % number of Monte Carlo realizations
    nReal = 128;
    
    % time-interval of analysis
    t0    = 1;             % initial time  (weeks)
    t1    = t0+nEW-1;      % final time    (weeks)
    dt    = 1;             % time step     (weeks)
    tspan = (t0:dt:t1)';   % temporal mesh
    
    % step size between indices
    stride = 1;
    
    % time-lag for climate variables
    lag_T = -9;
    lag_P = -9;
    lag_H = -9;
    
    ModelStruct1.r0         = 0.5;
    ModelStruct1.K          = 500e3;
    ModelStruct1.q          = 1;
    ModelStruct1.p          = 2;
    ModelStruct1.alpha      = 1.5;
    ModelStruct1.m          = 2;
    ModelStruct1.delta      = 1;
    ModelStruct1.beta       = 5;
    ModelStruct1.T_min      = 18.0;    % Paper Frontiers 2023
    ModelStruct1.T_max      = 32.0;    % Paper Frontiers 2023
    ModelStruct1.P_min      = 0.1;     % Paper Frontiers 2023
    ModelStruct1.P_max      = 30.0;    % Paper Frontiers 2023
    ModelStruct1.H_min      = 60.0;    % Paper Frontiers 2023
    ModelStruct1.H_max      = 80.0;    % Paper Frontiers 2023
    ModelStruct1.T_data     = DataTrain_T;
    ModelStruct1.P_data     = DataTrain_P;
    ModelStruct1.H_data     = DataTrain_H;
    ModelStruct1.T_baseline = T_baseline;
    ModelStruct1.P_baseline = P_baseline;
    ModelStruct1.H_baseline = H_baseline;
    ModelStruct1.T          = zeros(nEW,1);
    ModelStruct1.P          = zeros(nEW,1);
    ModelStruct1.H          = zeros(nEW,1);
    ModelStruct1.C0         = DataTrain_prevalence(1,:);
    ModelStruct1.tspan      = tspan;
    ModelStruct1.nReal      = nReal;
    ModelStruct1.winLen     = nEW;
    ModelStruct1.stride     = stride;
    ModelStruct1.lag_T      = lag_T;
    ModelStruct1.lag_P      = lag_P;
    ModelStruct1.lag_H      = lag_H;

    % ======================================
    % solve the calibration inverse problem
    % ======================================
    
    % stochastic model function
    fun1 = @(x) MyModel(x,ModelStruct1);
    
    % Names for the model parameters 
    paramNames = { ...
      'r0', ...
      'K', ...
      'q', ...
      'p', ...
      'alpha', ...
      'r0_cv', ...
      'K_cv', ...
      'q_cv', ...
      'p_cv', ...
      'alpha_cv',  ...
      'lag_T',...
      'lag_P',...
      'lag_H'
    };
    
    % Bounds for the model parameters 
    r0_min = 0.0;
    r0_max = 5.0;

    K_min = round(min(DataTrain_prevalence(end,:)));
    K_max = round(max(DataTrain_prevalence(end,:)));
    
    q_min = 0.0;
    q_max = 1.0;
        
    p_min = 1.0;
    p_max = 10.0;
    
    alpha_min = 1.0;
    alpha_max = 2.0;
    
    r0_cv_min = 0.0;
    r0_cv_max = 1.0/sqrt(2);
    
    K_cv_min = 0.0;
    K_cv_max = 1.0/sqrt(3);
    
    q_cv_min = 0.0;
    q_cv_max = 1.0/sqrt(3);
    
    p_cv_min = 0.0;
    p_cv_max = 1.0/sqrt(2);
    
    alpha_cv_min = 0.0;
    alpha_cv_max = 1.0/sqrt(3);
    
    lag_min = -12;
    lag_max = -2;
    
    lb = [r0_min    K_min    q_min    p_min    alpha_min ...
          r0_cv_min K_cv_min q_cv_min p_cv_min alpha_cv_min ...
          lag_min   lag_min  lag_min]';
    ub = [r0_max    K_max    q_max    p_max    alpha_max ...
          r0_cv_max K_cv_max q_cv_max p_cv_max alpha_cv_max ...
          lag_max   lag_max  lag_max]';
    
    % initial guess for the model parameters
    X0     = 0.5*(lb+ub);
    X0(2)  = mean(DataTrain_prevalence(end,:));
    X0(7)  = std(DataTrain_prevalence(end,:))/X0(2);
    
    % define the misfit function
    J = @(X) MisfitMeanVar(X,DataTrain_incidence,fun1);
    %J = @(X) MisfitMeanVar(X,DataTrain_prevalence,fun1);
    
    % set options for the optimizer
    %SolverOpt = optimset('Display','iter');
    SolverOpt = optimset('Display','none');
    
    % solve the model calibration inverse problem
    X_opt = fmincon(J,X0,[],[],[],[],lb,ub,@IntVarsConstraints,SolverOpt);
    
    % print the identified parameters on screen
    PrintIdentifiedParams(paramNames, X_opt);

    % ================================
    % define the trained model struct
    % ================================
    nReal                   = 1024;
    ModelStruct1.nReal      = nReal;
    ModelStruct2            = ModelStruct1;
    ModelStruct2.r0         = X_opt(1);
    ModelStruct2.K          = X_opt(2);
    ModelStruct2.q          = X_opt(3);
    ModelStruct2.p          = X_opt(4);
    ModelStruct2.alpha      = X_opt(5);
    %ModelStruct2.lag_T      = round(X_opt(11));
    %ModelStruct2.lag_P      = round(X_opt(12));
    %ModelStruct2.lag_H      = round(X_opt(13));
    ModelStruct2.C0         = DataTrain_prevalence(1,:);
    
    % ===================================
    % integration of the system dynamics
    % ===================================
    
    % nominal stochastic model function
    fun1 = @(x) MyModel(x,ModelStruct1);
    
    % trained stochastic model function
    fun2 = @(x) MyModel(x,ModelStruct2);
    
    % evaluate the nominal model
    [U_incidence_train,U_prevalence_train] = fun1(X_opt);
    
    % evaluate the trained model
    [U_incidence_valid,U_prevalence_valid] = fun2(X_opt);
    
     U_incidence_train = real(U_incidence_train);
    U_prevalence_train = real(U_prevalence_train);
     U_incidence_valid = real(U_incidence_valid);
    U_prevalence_valid = real(U_prevalence_valid);
    
    % QoIs for training and validation
    dC_train_median = median( U_incidence_train,2);
    dC_valid_median = median( U_incidence_valid,2);
    dC_train_mean   =   mean( U_incidence_train,2);
    dC_valid_mean   =   mean( U_incidence_valid,2);

     C_train_median = median(U_prevalence_train,2);
     C_valid_median = median(U_prevalence_valid,2);
     C_train_mean   =   mean(U_prevalence_train,2);
     C_valid_mean   =   mean(U_prevalence_valid,2);
    
    % confidence probability (percentual)
    Pc1 = 95;
    Pc2 = 90;
    Pc3 = 80;
    Pc4 = 50;
    
    % lower and upper percentiles
    r_plus1  = 0.5*(100 + Pc1);
    r_plus2  = 0.5*(100 + Pc2);
    r_plus3  = 0.5*(100 + Pc3);
    r_plus4  = 0.5*(100 + Pc4);

    r_minus1 = 0.5*(100 - Pc1);
    r_minus2 = 0.5*(100 - Pc2);
    r_minus3 = 0.5*(100 - Pc3);
    r_minus4 = 0.5*(100 - Pc4);
    
    % confidence bands lower and upper bounds
    dC_train_low      = zeros(4,nEW);
    dC_train_upp      = zeros(4,nEW);

    dC_train_low(1,:) = prctile(U_incidence_train',r_minus1);
    dC_train_low(2,:) = prctile(U_incidence_train',r_minus2);
    dC_train_low(3,:) = prctile(U_incidence_train',r_minus3);
    dC_train_low(4,:) = prctile(U_incidence_train',r_minus4);
    dC_train_upp(1,:) = prctile(U_incidence_train',r_plus1);
    dC_train_upp(2,:) = prctile(U_incidence_train',r_plus2);
    dC_train_upp(3,:) = prctile(U_incidence_train',r_plus3);
    dC_train_upp(4,:) = prctile(U_incidence_train',r_plus4);

    C_train_low      = zeros(4,nEW);
    C_train_upp      = zeros(4,nEW);

    C_train_low(1,:) = prctile(U_prevalence_train',r_minus1);
    C_train_low(2,:) = prctile(U_prevalence_train',r_minus2);
    C_train_low(3,:) = prctile(U_prevalence_train',r_minus3);
    C_train_low(4,:) = prctile(U_prevalence_train',r_minus4);
    C_train_upp(1,:) = prctile(U_prevalence_train',r_plus1);
    C_train_upp(2,:) = prctile(U_prevalence_train',r_plus2);
    C_train_upp(3,:) = prctile(U_prevalence_train',r_plus3);
    C_train_upp(4,:) = prctile(U_prevalence_train',r_plus4);
    
    dC_valid_low      = zeros(4,nEW);
    dC_valid_upp      = zeros(4,nEW);
    
    dC_valid_low(1,:) = prctile(U_incidence_valid',r_minus1);
    dC_valid_low(2,:) = prctile(U_incidence_valid',r_minus2);
    dC_valid_low(3,:) = prctile(U_incidence_valid',r_minus3);
    dC_valid_low(4,:) = prctile(U_incidence_valid',r_minus4);
    dC_valid_upp(1,:) = prctile(U_incidence_valid',r_plus1);
    dC_valid_upp(2,:) = prctile(U_incidence_valid',r_plus2);
    dC_valid_upp(3,:) = prctile(U_incidence_valid',r_plus3);
    dC_valid_upp(4,:) = prctile(U_incidence_valid',r_plus4);
    
    C_valid_low      = zeros(4,nEW);
    C_valid_upp      = zeros(4,nEW);
    
    C_valid_low(1,:) = prctile(U_prevalence_valid',r_minus1);
    C_valid_low(2,:) = prctile(U_prevalence_valid',r_minus2);
    C_valid_low(3,:) = prctile(U_prevalence_valid',r_minus3);
    C_valid_low(4,:) = prctile(U_prevalence_valid',r_minus4);
    C_valid_upp(1,:) = prctile(U_prevalence_valid',r_plus1);
    C_valid_upp(2,:) = prctile(U_prevalence_valid',r_plus2);
    C_valid_upp(3,:) = prctile(U_prevalence_valid',r_plus3);
    C_valid_upp(4,:) = prctile(U_prevalence_valid',r_plus4);
    
    % ================
    % post-processing
    % ================

    % Prepare data for output table (ensure they are column vectors)
    lower95 = round(dC_valid_low(1,:))';
    lower90 = round(dC_valid_low(2,:))';
    lower80 = round(dC_valid_low(3,:))';
    lower50 = round(dC_valid_low(4,:))';
    pred    = round(dC_valid_median);
    upper50 = round(dC_valid_upp(4,:))';
    upper80 = round(dC_valid_upp(3,:))';
    upper90 = round(dC_valid_upp(2,:))';
    upper95 = round(dC_valid_upp(1,:))';
    
    % Data field for output table
    DataFields = {'date'     ,...
                  'lower_95' ,...
                  'lower_90' ,...
                  'lower_80' ,...
                  'lower_50' ,...
                  'pred'     ,...
                  'upper_50' ,...
                  'upper_80' ,...
                  'upper_90' ,...
                  'upper_95'
                 };

    % Define output table
    OutputDataTable = table(dates_valid,...
                            lower95,    ...
                            lower90,    ...
                            lower80,    ...
                            lower50,    ...
                            pred,       ...
                            upper50,    ...
                            upper80,    ...
                            upper90,    ...
                            upper95,    ...
                            'VariableNames',DataFields);

    % Save the output table to a CSV file
    writetable(OutputDataTable,[FileNameCSV_out,current_uf,'.csv']);
    
    % custom colors
    MyRed         = [0.6350 0.0780 0.1840];
    MyLightRed    = [0.8175 0.5390 0.5920];
    MyGreen       = [0.0000 0.5000 0.0000];
    MyLightGreen  = [0.5000 0.7500 0.5000];
    MyBlue        = [0.0000 0.4470 0.7410];
    MyLightBlue   = [0.5000 0.7235 0.8705];
    MyOrange      = [0.8500 0.3250 0.0980];
    MyLightOrange = [0.9250 0.6625 0.5490];
    MyPink        = [1.0000 0.5000 0.7500];
    MyLightPink   = [1.0000 0.7500 0.8500];
    
    % ..........................................................
    graphObj1.gname   = [num2str(case_name),'_Incidence_',current_uf];
    graphObj1.title     = 'Validation Test 3: 2024-2025 Season';
    graphObj1.xmin      = dates_valid(1);
    graphObj1.xmax      = dates_valid(end);
    graphObj1.ymin      = 0;
    graphObj1.ymax      = 'auto';
    graphObj1.xlab      = '';
    graphObj1.ylab      = 'Probable Cases \times 10^3 (Incidence)';
    graphObj1.colorMean = MyBlue;
    graphObj1.colorMed  = MyOrange;
    graphObj1.legData   = 'Validation Data';
    graphObj1.legMean   = 'Mean';
    graphObj1.legMed    = 'Median';
    graphObj1.legBand   = { ...
       '95% envelope', ...
       '90% envelope', ...
       '80% envelope', ...
       '50% envelope'  ...
    };
    graphObj1.signature = 'Authors: A. Cunha Jr et al. (D-FENSE team)';
    graphObj1.print     = 'yes';
    graphObj1.close     = 'no';
    
    fig1 = graph_QoI_UQ_4bands(dates_valid,DataValid_incidence/1000,...
                                           dC_valid_mean/1000,...
                                           dC_valid_median/1000,...
                                           dC_valid_low/1000, ...
                                           dC_valid_upp/1000,graphObj1);
    % ..........................................................

    % ..........................................................
    graphObj2.gname   = [num2str(case_name),'_Prevalence_',current_uf];
    graphObj2.title     = 'Validation Test 3: 2024-2025 Season';
    graphObj2.xmin      = dates_valid(1);
    graphObj2.xmax      = dates_valid(end);
    graphObj2.ymin      = 0;
    graphObj2.ymax      = 'auto';
    graphObj2.xlab      = '';
    graphObj2.ylab      = 'Probable Cases \times 10^3 (Prevalence)';
    graphObj2.colorMean = MyBlue;
    graphObj2.colorMed  = MyOrange;
    graphObj2.legData   = 'Data';
    graphObj2.legMean   = 'Mean';
    graphObj2.legMed    = 'Median';
    graphObj2.legBand   = { ...
        '95% envelope', ...
        '90% envelope', ...
        '80% envelope', ...
        '50% envelope'  ...
        };
    graphObj2.signature = 'Authors: A. Cunha Jr et al. (D-FENSE team)';
    graphObj2.print     = 'yes';
    graphObj2.close     = 'no';

    fig2 = graph_QoI_UQ_4bands(dates_valid,DataValid_prevalence/1000,...
                                            C_valid_mean/1000,...
                                            C_valid_median/1000,...
                                            C_valid_low/1000, ...
                                            C_valid_upp/1000,graphObj2);
    % ..........................................................

end

% create a directory to store the saved files
mkdir(DirNameCSV_out)

% move files for a proper directory
movefile('*.csv',DirNameCSV_out)
movefile('*.eps',DirNameCSV_out)
movefile('*.png',DirNameCSV_out)
% -----------------------------------------------------------


% Program execution time
% -----------------------------------------------------------
disp(' ');
disp(' -----------------------------');
disp('            THE END!          ');
disp(' -----------------------------');
disp('  Total execution time:       ');
disp(['  ',num2str(toc(timeStart)),' seconds']);
disp(' -----------------------------');
% -----------------------------------------------------------



% Integer variables constraints
% -----------------------------------------------------------
function [ineqnonlin,eqnonlin] = IntVarsConstraints(X)
    ineqnonlin = [];
    eqnonlin   =[mod(X(2),1); mod(X(11:13),1)];
end
% -----------------------------------------------------------