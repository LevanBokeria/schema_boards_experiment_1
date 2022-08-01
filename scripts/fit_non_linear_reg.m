%% Description

%% Global setup
clear; clc; close all;
dbstop if error;

warning('off','MATLAB:table:RowsAddedExistingVars')
warning('off','MATLAB:rankDeficientMatrix')
warning('off','stats:nlinfit:IllConditionedJacobian')
warning('off','stats:nlinfit:IllConditionedJacobian')

saveData = 1;
qc_filter = 0;

%% Load and prepare the dataset
opts = detectImportOptions('./results/mean_by_rep_long_all_types.csv');
opts = setvartype(opts,{'border_dist_closest'},'char');

df = readtable('./results/mean_by_rep_long_all_types.csv',opts);

% Load the qc pass data
opts = detectImportOptions('./results/qc_check_sheets/qc_table.csv');
opts = setvartype(opts,{'qc_fail_overall'},'logical');

qc_pass = readtable('./results/qc_check_sheets/qc_table.csv',opts);
qc_pass_ptp = qc_pass.ptp(~qc_pass.qc_fail_overall);

% Get only the needed accuracy types
indices = strcmp(df.border_dist_closest,'all');
df = df(indices,:);

if qc_filter
    % Get only qc pass
    indices = ismember(df.ptp,qc_pass_ptp);
    df = df(indices,:);
end

all_ptp = unique(df.ptp);
n_ptp   = length(all_ptp);

all_conditions        = unique(df.condition);
all_hidden_pa_types   = unique(df.hidden_pa_img_type);
all_border_dist_types = unique(df.border_dist_closest);

%% Start the for loop
params_two   = [200,0.1];

params_three = [150,0.1,180];

plotFMSEstimation = 0;

tbl = table;

ctr = 1;
for iPtp = 1:n_ptp
    iPtp
    
    for iCond = 1:length(all_conditions)
%         all_conditions{iCond}
        
        for iType = 1:length(all_hidden_pa_types)
%             iType

            warning('');

%             if strcmp(all_conditions{iCond},'no_schema') | strcmp(all_conditions{iCond},'random_loc')
%                 
%                 if strcmp(all_hidden_pa_types{iType},'near') | strcmp(all_hidden_pa_types{iType},'far')
%                     
%                     continue;
%                     
%                 end
%                 
%             end
            
            curr_ptp  = all_ptp{iPtp};
            curr_cond = all_conditions{iCond};
            curr_type = all_hidden_pa_types{iType};
            
            % Get the data
            y = df.mouse_error_mean(strcmp(df.ptp,curr_ptp) &...
                strcmp(df.condition,curr_cond) & ...
                strcmp(df.hidden_pa_img_type,curr_type));
            
            % Now fit the data
            X = (1:8)';

            modelfun_two_par = @(b,x)b(1) * exp(-b(2) * (x(:,1)-1));
            
            mdl_two_par = fitnlm(X,y,modelfun_two_par,params_two);
            
            % Three parameter
            modelfun_three_par = @(b,x)b(1) * (exp(-b(2) * (x(:,1)-1)) - 1) + b(3);

            try
                
                mdl_three_par = fitnlm(X,y,modelfun_three_par,params_three);
                
            catch e
               
                tbl.errorMsg{ctr} = e.message;
                
            end
            
            [warnMsg, warnId] = lastwarn;
            
            if ~isempty(warnMsg)
                                
                % Plot
%                 figure
%                 plot(mdl_three_par.Variables.y)
%                 hold on
%                 plot(mdl_three_par.predict)
                w = warning('query','last');
                
                warning('off',w.identifier);
                
                tbl.warnMsg{ctr} = warnMsg;
                tbl.warnId{ctr}  = warnId;
                
                warning('');
                % Try fminsearch!
                [out_three_params,fval_three_param] = est_learning_rate(y',params_three,plotFMSEstimation,'three_parameters');
                
                % Record fminsearch output
                w = warning('query','last');
                
                tbl.fminsearch_three_param{ctr} = out_three_params;
                tbl.fminsearch_message{ctr} = w.identifier;

            end

            % Save in a table
            tbl.ptp{ctr} = curr_ptp;
            tbl.condition{ctr} = curr_cond;
            tbl.hidden_pa_img_type{ctr} = curr_type;
            tbl.sse_two_param(ctr) = mdl_two_par.SSE;
            tbl.intercept_two_param(ctr) = mdl_two_par.Coefficients.Estimate(1);
            tbl.learning_rate_two_param(ctr) = mdl_two_par.Coefficients.Estimate(2);
            tbl.sse_three_param(ctr) = mdl_three_par.SSE;
            tbl.intercept_three_param(ctr) = mdl_three_par.Coefficients.Estimate(3);
            tbl.learning_rate_three_param(ctr) = mdl_three_par.Coefficients.Estimate(2);
            tbl.asymptote_three_param(ctr) = mdl_three_par.Coefficients.Estimate(3) - mdl_three_par.Coefficients.Estimate(1);
            
            ctr = ctr + 1;
        end %itype
    end % iCond
end %iPtp

%% Save the table
if saveData
    writetable(tbl,'./results/learning_rate_fits_matlab.csv');
end
