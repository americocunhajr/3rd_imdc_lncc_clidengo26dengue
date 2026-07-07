% -----------------------------------------------------------------
% BetaLogisticModel.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Feb 13, 2025
%            Last update in: Jul 29, 2026
% -----------------------------------------------------------------
%  This function defines the ODE for the beta-logistic growth model,
%  with growth rate optionally modulated by temperature via a smooth
%  Briere function:
%  
%          dCdt = r_eff*(C^q)*(1-(C/K)^alpha)^p
%  
%  with r_eff = r0 * Briere(T_t,P_t,H_t).
%  
%
%  Model quantity                                   Unit
%  C        = cumulative number of probable cases   (individuals)
%  dCdt     = probable cases rate of change         (individuals/time)
%  r0       = baseline growth rate (r0 > 0)         (time^-1)
%  K        = epidemic final size (K > 0)           (individuals)
%  q        = initial growth profile (0 <= q <=1)   (dimensionless)
%  p        = late-time growth rate (p >= 1)        (dimensionless)
%  alpha    = degree of asymmetry (alpha >= 0)      (dimensionless)
%  m        = Briere asymmetry factor               (dimensionless)
%  delta    = Briere fitting factor                 (dimensionless)
%  beta     = boundary smoothness factor            (dimensionless)
%  r_inf    = final growth rate                     (time^-1)
%  eta      = rate of change for beta               (time^-1)
%  tau_beta = growth rate inflection time           (time   )
%  T_min    = minimum temperature threshold         (temperature)
%  T_max    = maximum temperature threshold         (temperature)
%  T        = temperature time series               (temperature)
%  P_min    = minimum precipitation threshold       (length/time)
%  P_max    = maximum precipitation threshold       (length/time)
%  P        = precipitation time series             (length/time)
%  H_min    = minimum relative humidity threshold   (%)
%  H_max    = maximum relative humidity threshold   (%)
%  H        = relative humidity time series         (%)
%  tspan    = temporal mesh                         (time)
% -----------------------------------------------------------------
function dCdt = BetaLogisticModel(t,C,ModelStruct)

    % model parameters
    r0      = ModelStruct.r0;
    K       = ModelStruct.K;
    q       = ModelStruct.q;
    p       = ModelStruct.p;
    alpha   = ModelStruct.alpha;

    m       = ModelStruct.m;
    delta   = ModelStruct.delta;
    beta    = ModelStruct.beta;

    T_min   = ModelStruct.T_min;
    T_max   = ModelStruct.T_max;
    P_min   = ModelStruct.P_min;
    P_max   = ModelStruct.P_max;
    H_min   = ModelStruct.H_min;
    H_max   = ModelStruct.H_max;

    T       = ModelStruct.T;
    P       = ModelStruct.P;
    H       = ModelStruct.H;

    tspan   = ModelStruct.tspan;

    % % Interpolate climate forcing in time
    % T_t = interp1(tspan,T,t,'linear','extrap');
    % P_t = interp1(tspan,P,t,'linear','extrap');
    % H_t = interp1(tspan,H,t,'linear','extrap');
    % 
    % % Evaluate Briere suitability directly at T(t), P(t), H(t).
    % Briere_T_t = BriereSmooth(T_t,T_min,T_max,1,m,delta,beta);
    % Briere_P_t = BriereSmooth(P_t,P_min,P_max,1,m,delta,beta);
    % Briere_H_t = BriereSmooth(H_t,H_min,H_max,1,m,delta,beta);
    % 
    % % Normalize suitability functions using reference grids
    % nGrid = 100;
    % 
    % T_grid = linspace(T_min,T_max,nGrid)';
    % P_grid = linspace(P_min,P_max,nGrid)';
    % H_grid = linspace(H_min,H_max,nGrid)';
    % 
    % Briere_T_ref = BriereSmooth(T_grid,T_min,T_max,1,m,delta,beta);
    % Briere_P_ref = BriereSmooth(P_grid,P_min,P_max,1,m,delta,beta);
    % Briere_H_ref = BriereSmooth(H_grid,H_min,H_max,1,m,delta,beta);
    % 
    % maxT = max(Briere_T_ref);
    % maxP = max(Briere_P_ref);
    % maxH = max(Briere_H_ref);
    % 
    % if maxT > 0
    %     Briere_T_t = Briere_T_t./maxT;
    % end
    % if maxP > 0
    %     Briere_P_t = Briere_P_t./maxP;
    % end
    % if maxH > 0
    %     Briere_H_t = Briere_H_t./maxH;
    % end

    % compute Briere modifiers for climate variables
    Briere_T = BriereSmooth(T,T_min,T_max,1,m,delta,beta);
    Briere_P = BriereSmooth(P,P_min,P_max,1,m,delta,beta);
    Briere_H = BriereSmooth(H,H_min,H_max,1,m,delta,beta);

    % normalize Briere modifiers (0 <= Briere <= 1)
    maxT = max(Briere_T);
    maxP = max(Briere_P);
    maxH = max(Briere_H);

    if maxT > 0
        Briere_T = Briere_T./maxT;
    end
    if maxP > 0
        Briere_P = Briere_P./maxP;
    end
    if maxH > 0
        Briere_H = Briere_H./maxH;
    end

    % interpolate climate variables at current time
    T_t = interp1(tspan,T,t,'linear','extrap');
    P_t = interp1(tspan,P,t,'linear','extrap');
    H_t = interp1(tspan,H,t,'linear','extrap');

    % interpolate Briere modifiers at current time
    Briere_T_t = interp1(T,Briere_T,T_t);
    Briere_P_t = interp1(P,Briere_P,P_t);
    Briere_H_t = interp1(H,Briere_H,H_t);

    % Climate multiplier
    %Briere_t = Briere_T_t .* Briere_P_t .* Briere_H_t;
    %Briere_t = (Briere_T_t + Briere_P_t + Briere_H_t)/3;
    Briere_t = (Briere_T_t .* Briere_P_t .* Briere_H_t).^(1/3);

    % effective growth rate
    %r_eff = r0;
    %r_eff = r0 .* Briere_t;
    r_eff = r0 .* (Briere_t+1);

    % beta-logistic differential equation
    dCdt = r_eff .* (C.^q) .* (1 - (C./K).^alpha).^p;

    % avoid small complex/negative numerical artifacts
    dCdt = real(dCdt);
end
% -----------------------------------------------------------------
