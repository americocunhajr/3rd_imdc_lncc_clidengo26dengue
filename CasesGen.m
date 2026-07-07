% -----------------------------------------------------------------
% CasesGen.m
% -----------------------------------------------------------------
%  Programmers: Americo Cunha Jr
%               americo.cunhajr@gmail.com
%
%  Originally programmed in: Jul 03, 2026
%            Last update in: Jul 03, 2026
% -----------------------------------------------------------------
% Generates synthetic epidemic incidence curves from historical
% seasonal incidence data.
%
% Input:
%   DataCases      - nWeeks x nSeasons matrix of historical weekly cases
%   nReal          - number of synthetic realizations
%
% Output:
%   syntheticCases - nWeeks x nReal matrix of synthetic weekly cases
%
% Method:
%   1. Decompose each season into final size and normalized shape:
%          I_s(t) = K_s f_s(t)
%   2. Model log(K_s) as Gaussian.
%   3. Model the epidemic shape f_s(t) with a logistic-normal model.
%   4. Generate new positive normalized shapes.
%   5. Reconstruct incidence:
%          I_new(t) = K_new f_new(t)
% -----------------------------------------------------------------
function syntheticCases = CasesGen(DataCases,nReal)

    % -----------------------------
    % input checks
    % -----------------------------
    if nargin < 2
        error('Too few inputs.');
    elseif nargin > 2
        error('Too many inputs.');
    end

    if ~isnumeric(DataCases) || ~ismatrix(DataCases)
        error('DataCases must be a numeric matrix.');
    end

    if ~isscalar(nReal) || nReal <= 0 || mod(nReal,1) ~= 0
        error('nReal must be a positive integer.');
    end

    % -----------------------------
    % dimensions
    % -----------------------------
    [nWeeks,nSeasons] = size(DataCases);

    if nSeasons < 2
        error('At least two historical seasons are required.');
    end

    % -----------------------------
    % clean data
    % -----------------------------
    DataCases = real(DataCases);
    DataCases = max(DataCases,0);

    % final epidemic sizes
    K_hist = sum(DataCases,1);

    % remove seasons with zero total cases
    validSeasons = K_hist > 0;
    DataCases = DataCases(:,validSeasons);
    K_hist = K_hist(validSeasons);

    [nWeeks,nSeasons] = size(DataCases);

    if nSeasons < 2
        error('At least two nonzero historical seasons are required.');
    end

    % -----------------------------
    % normalized epidemic shapes
    % -----------------------------
    F_hist = DataCases ./ K_hist;

    % numerical floor for log transform
    epsShape = 1.0e-8;

    % logistic-normal representation
    Y_hist = log(F_hist + epsShape);

    % center log-shapes
    muY = mean(Y_hist,2);
    RY  = Y_hist - muY;

    % covariance of log-shape residuals
    SigmaY = cov(RY');

    % regularization
    SigmaY = 0.5*(SigmaY + SigmaY');

    jitter = 1.0e-10 * trace(SigmaY)/max(nWeeks,1);
    if jitter <= 0 || ~isfinite(jitter)
        jitter = 1.0e-10;
    end

    SigmaY = SigmaY + jitter*eye(nWeeks);

    % -----------------------------
    % final size model
    % -----------------------------
    logK = log(K_hist(:));

    muLogK  = mean(logK);
    stdLogK = std(logK);

    if stdLogK < eps
        stdLogK = 0;
    end

    % -----------------------------
    % generate synthetic shapes
    % -----------------------------
    [L,pFlag] = chol(SigmaY,'lower');

    if pFlag ~= 0
        % fallback through eigenvalue correction
        [V,D] = eig(SigmaY);
        d = diag(D);
        d = max(d,1.0e-10);
        SigmaY = V*diag(d)*V';
        SigmaY = 0.5*(SigmaY + SigmaY');
        L = chol(SigmaY,'lower');
    end

    Z = randn(nWeeks,nReal);

    Y_new = muY + L*Z;

    F_new = exp(Y_new);

    % normalize each synthetic shape
    F_new = F_new ./ sum(F_new,1);

    % -----------------------------
    % generate final sizes
    % -----------------------------
    if stdLogK > 0
        K_new = exp(muLogK + stdLogK*randn(1,nReal));
    else
        K_new = exp(muLogK)*ones(1,nReal);
    end

    % -----------------------------
    % reconstruct incidence
    % -----------------------------
    syntheticCases = F_new .* K_new;

    % nonnegative integer weekly cases
    syntheticCases = max(real(syntheticCases),0);
    syntheticCases = round(syntheticCases);

end
% -----------------------------------------------------------------