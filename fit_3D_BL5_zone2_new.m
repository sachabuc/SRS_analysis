clear all;
close all;
cd /Users/virginie/Documents/Data/coherent_Raman/corals_12_23
addpath(genpath('/Users/virginie/Documents/Data/coherent_Raman/corals_12_23/SRS/SRS_data'));
data_clean_filename = '/Users/virginie/Documents/Data/coherent_Raman/corals_12_23/SRS/SRS_data/data_3D_aligned/BL5_zone_2_clean.mat';
load('FRANCE.mat');
load(data_clean_filename);
wn_clean
fit_result_filename = '/Users/virginie/Documents/Data/coherent_Raman/corals_12_23/SRS/SRS_data/data_3D_aligned/fit_BL5_zone_2_clean_3D_28_09_24.mat';
load_exist =0;
if load_exist ==1
load(fit_result_filename);
fit_result_filename = '/Users/virginie/Documents/Data/coherent_Raman/corals_12_23/SRS/SRS_data/data_3D_aligned/fit_BL5_zone_2_clean_3D_28_09_24_suite.mat';
end;


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Plot en Z
for jj = 1
    cut_1 = 328;   %560
    cut_2 = 335-200; %335
    delta_1 = 120;
    for k=1:6
        figure(1); subplot(1,6,k);
        I_max = max(max(data_clean(cut_1:cut_1,cut_2-delta_1:cut_2+delta_1,11:28,k)));
        imagesc((squeeze(data_clean(cut_1:cut_1,cut_2-delta_1:cut_2+delta_1,11:28,k)))); caxis([0 10]); colorbar;
    end;
    drawnow;
end;stop
%% relevant position along z = 11:24, along wn de 1 à 5
wn= wn_clean(1:5);
stack4D_align = data_clean(:,:,11:28,1:5); %11:24

for kw = 1: size(stack4D_align, 4)
    for ll = 1:size(stack4D_align, 3)
        stack4D_align_smooth(:,:,ll,kw) = smoothdata(stack4D_align(:,:,ll,kw), 'movmean', 3); 
    end;
end;
%spectrum = permute(data_clean(:,:,11:24,1:5), [4, 1, 2, 3]);
spectrum = permute(stack4D_align, [4, 1, 2, 3]);

%%
%stack4D_align_smooth = stack4D_align;
pos_3 = 8;
figure(10); subplot(2,2,1); imagesc(stack4D_align_smooth(:,:,pos_3 ,4)); caxis([0 30]); colorbar;
subplot(2,2,2); imagesc(stack4D_align_smooth(:,:,pos_3 ,2)); caxis([0 10]); colorbar;
subplot(2,2,3); imagesc((stack4D_align_smooth(:,:,pos_3 ,4)-stack4D_align_smooth(:,:,pos_3 ,2))./(stack4D_align_smooth(:,:,pos_3,2)+stack4D_align_smooth(:,:,pos_3 ,4))); caxis([-0.5 1]); colorbar;
subplot(2,2,4); imagesc((stack4D_align_smooth(:,:,pos_3 ,4)-stack4D_align_smooth(:,:,pos_3 ,5))./(stack4D_align_smooth(:,:,pos_3,5)+stack4D_align_smooth(:,:,pos_3 ,4))); caxis([-0.5 1]); colorbar;

%% Expression SRS
%pure aragonite (592,159)
%ACC (115, 541)
%CCHH (119 531)
tic
wn_cont = [1060:1:1100];
L3=size(stack4D_align, 3);
L2=size(stack4D_align, 2);
L1=size(stack4D_align, 1);
% Amp_1 = zeros(size(stack4D_align(:,:,:,1)));
% Amp_2 = zeros(size(stack4D_align(:,:,:,1)));
% Amp_3 = zeros(size(stack4D_align(:,:,:,1)));
% freq_1 = zeros(size(stack4D_align(:,:,:,1)));
% bck = zeros(size(stack4D_align(:,:,:,1)));
% error = zeros(size(stack4D_align(:,:,:,1)));

%%
for pos_3 =  15:18 %11 à 24 --> 11 à 28
    %pos_3
    for pos_2 = 1:L2
        parfor pos_1 = 1:L1
            t = wn.';
            y_SRS = spectrum(:,pos_1, pos_2, pos_3);
            %figure(2); clf;  
            Amplitude_1 = 3.4;
            Amplitude_2 = 7;
            Amplitude_3 = 3.5;
            frequence_1 = 1075;
            frequence_2 = 1086;
            %frequence_3 = 1095.5;
            frequence_3 = 1097;
            gamma_1 =10; %10 for a FWHM of 20 cm-1
            gamma_2 =5.22; %5.22 optimized on a two different aragonite peaks
            gamma_3 =5.22; %5.22 optimized on a aragonite peak, should be equal to the aragonite one
            background = 1;
            
            modelfunSRS = @(x,xdata)abs(x(5))+imag(abs(x(1))*(1./(xdata-x(2)-1i*gamma_1))) + ...
                imag(abs(x(3))*(1./(xdata-frequence_2-1i*gamma_2))) + imag(abs(x(4))*(1./(xdata-frequence_3-1i*gamma_3))) ;
            x0_SRS = [Amplitude_1 frequence_1 Amplitude_2  Amplitude_3 background ]; %valeurs de départ
            
            LB_SRS = [0   1065 0   0   0];
            UB_SRS = [100 1084 150   30   2];
            
            [x,resnorm,~,exitflag,output] = lsqcurvefit(modelfunSRS,x0_SRS,t,y_SRS,LB_SRS, UB_SRS);
            %x
            %resnorm
            Amp_1(pos_1, pos_2, pos_3) = abs(x(1));
            Amp_2(pos_1, pos_2, pos_3) = abs(x(3));
            Amp_3(pos_1, pos_2, pos_3) = abs(x(4));
            freq_1(pos_1, pos_2, pos_3) = x(2);
            bck(pos_1, pos_2,pos_3) = abs(x(5));
            error(pos_1, pos_2, pos_3) = resnorm;
            %figure(2); plot(wn_cont,modelfunSRS(x,wn_cont), 'o-'); hold on; plot(t,y_SRS, 'r-o');
        end;
    end;
    
    figure(6+pos_3*10);
    subplot(2,3,1); imagesc(Amp_1(:,:,pos_3)); caxis([2 30]); colorbar; title('ACC')
    subplot(2,3,2); imagesc(Amp_2(:,:,pos_3)); caxis([0 40]); colorbar;  title('CC')
    subplot(2,3,3); imagesc(Amp_3(:,:,pos_3)); caxis([2 15]); colorbar; title('high')
    subplot(2,3,4); imagesc(freq_1(:,:,pos_3)); caxis([1068 1084]); colorbar;
%     
%     
%     figure(8+pos_3*10); imagesc(bck(:,:,pos_3)); caxis([0.2 1.5]); colorbar; title('background')
%     figure(34); imagesc(error(:,:,pos_3)); caxis([0 5]); colorbar; title('error')
end;
toc
%%
frequence_1 = 1075;
frequence_2 = 1086;
frequence_3 = 1097;
gamma_1 = 10; %10 for a FWHM of 20 cm-1
gamma_2 = 5.22; %5.22 optimized on a two different aragonite peaks
gamma_3 = 5.22; %5.22 optimized on a aragonite peak, should be equal to the aragonite one

save(fit_result_filename,'fit_result_filename','Amp_1', 'Amp_2', 'Amp_3','freq_1', 'frequence_2', 'frequence_3', 'bck', 'spectrum', 'wn', 'error');   


