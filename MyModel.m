% -----------------------------------------------------------------
%  MyModel.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Jul 11, 2025
%            Last update in: Jun 16, 2026
% -----------------------------------------------------------------
%  This function evaluates the stochastic model output function 
%  given by the solution of a beta-logistic epidemic model and 
%  its derivative.
%
%  Input:
%  X           - (Nvars x 1) model parameters vector
%  ModelStruct - struct with the model quantities
%  
%  Output:
%  U_incidence  - (nSamp x nReal) matrix with incidence  realizations
%  U_prevalence - (nSamp x nReal) matrix with prevalence realizations 
% -----------------------------------------------------------------
function [U_incidence,U_prevalence] = MyModel(X,ModelStruct)

    % model hyperparameters
    tspan  = ModelStruct.tspan;  % temporal interval of analysis
    nSamp  = length(tspan);      % number of samples in each realization
    nReal  = ModelStruct.nReal;  % number of Monte Carlo realizations
    winLen = ModelStruct.winLen; % temporal window length
    stride = ModelStruct.stride; % step size between indices

    % initial conditions from data
    C0 = ModelStruct.C0;

    % update model parameters
	r0       = X(1);
	K        = X(2);
	q        = X(3);
	p        = X(4);
	alpha    = X(5);
	r0_cv    = X(6);
	K_cv     = X(7);
	q_cv     = X(8);
	p_cv     = X(9);
	alpha_cv = X(10);
	lag_T    = round(X(11));
    lag_P    = round(X(12));
    lag_H    = round(X(13));
    % lag_T_min = round(X(11));
    % lag_P_min = round(X(12));
    % lag_H_min = round(X(13));
    % lag_T_max = round(X(14));
    % lag_P_max = round(X(15));
    % lag_H_max = round(X(16));

    % generate synthetic climate time-series
    T_gen = ClimateGen(ModelStruct.T_data,...
                       ModelStruct.T_baseline,...
                       winLen,stride,nSamp,nReal);
    P_gen = ClimateGen(ModelStruct.P_data,...
                       ModelStruct.P_baseline,...
                       winLen,stride,nSamp,nReal);
    H_gen = ClimateGen(ModelStruct.H_data,...
                       ModelStruct.H_baseline,...
                       winLen,stride,nSamp,nReal);

    % apply the time-lag to account climate delay dependence
    T_gen = circshift(T_gen,lag_T);
    P_gen = circshift(P_gen,lag_P);
    H_gen = circshift(H_gen,lag_H);
    
    % hyper parameters for the stochastic model parameters
    r0_shape     = 1/r0_cv^2;
    r0_scale     = r0*r0_cv^2;
    K_min        = K*(1-sqrt(3)*K_cv);
    K_max        = K*(1+sqrt(3)*K_cv);
    q_min        = q*(1-sqrt(3)*q_cv);
    q_max        = q*(1+sqrt(3)*q_cv);
    p_shape      = 1/p_cv^2;
    p_scale      = p*p_cv^2;
    alpha_min    = alpha*(1-sqrt(3)*alpha_cv);
    alpha_max    = alpha*(1+sqrt(3)*alpha_cv);

    % generate realizations for the model parameters
    % ---    r0 ~ Gamma distribution
    % ---     K ~ Uniform distribution
    % ---     q ~ Uniform distribution
    % ---     p ~ Translated Gamma distribution
    % --- alpha ~ Uniform distribution
        r0_samp = gamrnd(r0_shape,r0_scale,[nReal,1]);
         K_samp = K_min + (K_max-K_min)*rand([nReal,1]);
         q_samp = q_min + (q_max-q_min)*rand([nReal,1]);
         p_samp = 1 + gamrnd(p_shape,p_scale,[nReal,1]);
     alpha_samp = alpha_min + (alpha_max-alpha_min)*rand([nReal,1]);
     % lag_T_samp = randi([lag_T_min,lag_T_max],[nReal,1]);
     % lag_P_samp = randi([lag_P_min,lag_P_max],[nReal,1]);
     % lag_H_samp = randi([lag_H_min,lag_H_max],[nReal,1]);

    % generate realizations for the initial conditions
    C0_gen = C0(ceil(numel(C0)*rand(nReal,1)));

    % preallocate memory for the model response
    U_incidence  = zeros(nSamp,nReal);
    U_prevalence = zeros(nSamp,nReal);

    % loop for Monte Carlo simulation
    for j=1:nReal

        % update the random parameters realizations
         ModelStruct.r0     =    r0_samp(j);
         ModelStruct.K      =     K_samp(j);
         ModelStruct.q      =     q_samp(j);
         ModelStruct.p      =     p_samp(j);
         ModelStruct.alpha  = alpha_samp(j);

        % update initial condition realization
        IC = C0_gen(j);
        
        % update climate time-series realization
        ModelStruct.T = T_gen(:,j);
        ModelStruct.P = P_gen(:,j);
        ModelStruct.H = H_gen(:,j);
        % ModelStruct.T = circshift(T_gen(:,j),lag_T_samp(j));
        % ModelStruct.P = circshift(P_gen(:,j),lag_P_samp(j));
        % ModelStruct.H = circshift(H_gen(:,j),lag_H_samp(j));
        
        % simulate the model using the current model parameters
        [~,C] = ode45(@(t,x)BetaLogisticModel(t,x,ModelStruct),tspan,IC);
           dC = diff(C);

         % j-th realization of the model response
         U_incidence(:,j)  = [dC; dC(end)];
         U_prevalence(:,j) = C;
    end
end
% -----------------------------------------------------------------