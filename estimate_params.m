%% Run Bayesian Parameter Estimation
%
% Use bayesian methods to estimate some of the parameters. First, set up
% our priors about the individual parameters, and locate the posterior
% mode. Then, run a posterior simulator (adaptive random-walk Metropolis)
% to obtain the whole distributions of the parameters.

%% Dependencies                                                            
%
% Run the following m-files before this one:
%
% * <read_model.html |read_model|>
% * <read_data.html |read_data|>
%


%% Clear Workspace
%
% Clear workspace, close all graphics figures, clear command window, and
% check the IRIS version.

clear
close all
clc
irisrequired 20180131


%% Load Solved Model Object and Historical Database
%
% Load the solved model object built |<read_model>|, and the historical
% database and dates created in |<read_data>|. 

load mat/read_model.mat m
load mat/read_data.mat d startHist endHist


%% Set Up Estimation Input Structure
%
% The estimation input struct describes which parameters to estimate and
% how to estimate them. A struct needs to be created with one field for
% each parameter that is to be estimated. Each parameter can be then
% assigned a cell array with up to four pieces of information:
%
%    estimSpecs.parameter_name = {start}
%    estimSpecs.parameter_name = {start, lower}
%    estimSpecs.parameter_name = {start, lower, upper}
%    estimSpecs.parameter_name = {start, lower, upper, dist}
%
% where |start| is a starting value for the iteration, |lower| and
% |upper| are the lower and upper bounds, respectively, and |dist| is a
% |distribution| object to specify the prior distribution on that
% parameter.
%
% If the starting value is |NaN|, then the currently assigned parameter
% value (from the model object) is used. The constants |-Inf| and |Inf| can
% be used for the lower and upper bounds, respectively. 

estimSpecs = struct( );

estimSpecs.chi = {NaN, 0.5, 0.95, distribution.Normal.fromMeanStd(0.85, 0.025)};
estimSpecs.xiw = {NaN, 30, 1000, distribution.Normal.fromMeanStd(60, 50)};
estimSpecs.xip = {NaN, 30, 1000, distribution.Normal.fromMeanStd(300, 50)};
estimSpecs.rhor = {NaN, 0.10, 0.95, distribution.Beta.fromMeanStd(0.85, 0.05)};
estimSpecs.kappap = {NaN, 1.5, 10, distribution.Normal.fromMeanStd(3.5, 1)};
estimSpecs.kappan = {NaN, 0, 1, distribution.Normal.fromMeanStd(0, 0.2)};

estimSpecs.std_Ep = {0.01, 0.001, 0.10, distribution.InvGamma.fromMeanStd(0.01, Inf)};
estimSpecs.std_Ew = {0.01, 0.001, 0.10, distribution.InvGamma.fromMeanStd(0.01, Inf)};
estimSpecs.std_Ea = {0.001, 0.0001, 0.01, distribution.InvGamma.fromMeanStd(0.001, Inf)};
estimSpecs.std_Er = {0.005, 0.001, 0.10, distribution.InvGamma.fromMeanStd(0.005, Inf)};
estimSpecs.corr_Er__Ep = {0, -0.9, 0.9, distribution.Normal.fromMeanStd(0, 0.5)};

disp(estimSpecs)

%% Visualize Prior Distributions
%
% The function |plotpp( )| plots the prior distributions (this function can
% also plot the priors together with posteriors obtained from a posterior
% simulator; see below). To control the appearance and graphics
% properties of the various plots included in the graphs, use either the
% options |Figure=|, |Axes=|, |Title=|, |PlotPrior=|, |PlotInit=|,
% |PlotMode=|, |PlotPoster=|, |PlotBounds=|, or alternatively the standard
% Matlab function |set( )| with the graphics handles returned in the struct
% |h|.

c = autocaption(m, estimSpecs, '$descript$');

[~, ~, h] = plotpp(estimSpecs, [ ], [ ], ...
    'Subplot=', [2, 3], 'Caption=', c);

ftitle(h.figure, 'Prior Distributions');

%% Maximize Posterior Distribution to Locate Its Mode
%
% The main output arguments are the following (these remain the same
% whatever the set-up of the estimation):
%
% * |summary| -- Table with final estimates and other kinds of information
% on parameter estimates.
% * |pos| -- Initialized posterior simulator object. The object |pos| will
% be used later in this file to run a posterior simulator.
% * |C| -- Covariance matrix of the parameter estimates based on the
% asymptotical hessian of the posterior density at its mode.
% * |H| -- Cell array 1-by-2: |H{1}| is the hessian of the objective
% function returned by the Optim Tbx (should be close to |C|); |H{2}| is a
% diagonal matrix with the contributions of the priors to the total
% hessian.
% * |mest| -- Model object with the new estimated parameters.
% * |v| -- Estimate of the common variance factor (only with the option
% |Relative=true|, which is the default setting); all the std dev of all
% shocks are multiplied automatically by the square root of this number.
% * |delta| -- Estimates of the deterministic trend parameters estimated
% by concentrating them out of the likelihood function.

filterOpt = { ...
    'OutOfLik=', {'Short_', 'Infl_', 'Growth_', 'Wage_'}, ...
    'Relative=', true, ...
    'InitUnit=', 'ApproxDiffuse', ...
    };

optimSet = { ...
    'MaxFunEvals=', 10000, ...
    'MaxIter=', 100, ...
    };

[summary, pos, C, H, mest, v, delta, Pdelta] = ...
    estimate(m, d, startHist:endHist, estimSpecs, ...
    'Filter=', filterOpt, 'Summary=', 'Table'); %, 'OptimSet=', optimSet);


%% Print Some Estimation Results

summary

disp('Common variance factor');
v

disp('Out-of-lik parameters');
delta

disp('Parameters in the estimated model object');
disp('Std deviations adjusted for the common variance factor');
get(mest, 'parameters')

%% Visualize Prior Distributions and Posterior Modes
%
% Use the function |plotpp( )| again supplying now the struct |summary|
% with the estimated posterior modes as the second input argument. The
% posterior modes are added as stem graphs, and the estimated values are
% included in the graph titles.

[pr, po, h] = plotpp(estimSpecs, summary, [ ], ...
    'Title=', {'FontSize=', 8}, ...
    'Axes=', {'FontSize=', 8}, ...
    'PlotInit=', {'Color=', 'red', 'Marker=', '*'}, ...
    'Subplot=', [2, 3]); %#ok<ASGLU>

ftitle(h, 'Prior Distributions and Posterior Modes');
legend('Prior Density', 'Starting Value', 'Posterior Mode', ...
    'Lower Bound', 'Upper Bound');


%% Examine Neighbourhood Around Optimum
%
% The function |neighbourhood( )| evaluates the posterior density (accessible
% through the poster object |pos|) at a number of points around the optimum
% for each parameter. In the code below, each parameter estimate is
% examined within the range of +/- 5 % of the posterior mode (i.e., 
% |0.95 : 0.01 : 1.05| times the value of the estimate).
%
% The function |plotneigh( )| then visualize the local behaviour of both
% the overall objective funtion (minus log posterior density) and the data
% likelihood (minus log likelihood). Note that the likelihood curve is
% shifted up or down by an arbitrary constant to make it fit in the graph.
%
% The option |LinkAxes=| makes the y-axes identical in all graphs to help
% compare the curvature of the posterior density around the individual
% parameter estimates. This indicates the degree of identification.

n = neighbourhood(mest, pos, 0.95:0.005:1.05, ...
    'Progress=', true, 'Plot=', false)

plotneigh(n, 'LinkAxes=', true, 'Subplot=', [2, 3], ...
    'PlotObj=', {'LineWidth=', 2}, ...
    'PlotEst=', {'Marker=', 'o', 'LineWidth=', 2}, ...
    'PlotBounds=', {'LineStyle', '--', 'LineWidth', 2});


%% Run Metropolis Random Walk Posterior Simulator
%
% Run 5,000 draws from the posterior distribution using an adaptive version
% of the random-walk Metropolis algorithm. The number of draws, |N=1000|, 
% should be obviously much larger in practice (such as 100,000 or
% 1,000,000). Use then the function |stats| to calculate some statistics of
% the simulated parameter chains -- by default, the simulated chains, their
% means, std errors, high probability density intervals, and the marginal
% data density are returned. Feel free to change the list of requested
% characteristics; see help on |poster/stats| for details.
%
% The output argument |ar| monitors the evolution of the acceptance ratio.
% The default target acceptance ratio is 0.234 (can be modified using the
% option |TargetAR=| in |arwm( )|), the covariance of the proposal
% distribution is gradually adapted to achieve this target.

N = 1000

tic;
[theta, logpost, ar] = arwm(pos, N, ...
    'Progress=', true, 'AdaptScale=', 2, 'AdaptProposalCov=', 1, ...
    'BurnIn=', 0.20);
toc;

disp('Final acceptance ratio');
ar(end)

s = stats(pos, theta, logpost)

%% Visualize Priors and Posteriors
%
% Because the number of draws from the posterior distribution is very low, 
% |N=1000|, the posterior graphs are far from being smooth, and may visibly
% change if another posterior chain is generated.

[pr, po, h] = plotpp(estimSpecs, summary, theta, ...
    'PlotPrior=', {'LineStyle=', '--'}, ...
    'Title=', {'FontSize=', 8}, ...
    'Subplot=', [2, 3]);

ftitle(h.figure, 'Prior Distributions and Posterior Distributions');

legend('Prior Density', 'Posterior Mode', 'Posterior Density', ...
    'Lower Bound', 'Upper Bound');


%% Save Model Object with Estimated Parameters

save mat/estimate_params.mat mest pos estimSpecs theta logpost


%% Show Variables and Objects Created in This File                         

whos

