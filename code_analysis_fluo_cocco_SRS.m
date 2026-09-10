clear all;
close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Creating a FULL set of numerical DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cd '/Users/virginie/Documents/Data/coherent_Raman/These_Sacha/biblio/Beuvier_cdi_2019/data_CDI_2026'

data_filename = 'C:\Users\sacha.bucourt\Documents\Data lab\spectres\campagne cocco/RCC1216_M4bis_3D_coccosphere10_512-2026-03-17.mat';
reconstruction = load(data_filename);

data_3D_abs = abs(reconstruction.data);
[N1, N2, N3] = size(data_3D_abs);

%% Creating the distribition maps of 2 mineral phases and fluorophore distribution
calcite_map = data_3D_abs(:,:,N3/2);
ACC_map = zeros(size(calcite_map));
ACC_map(70:100,10:30) = data_3D_abs(70:100,10:30,N3/2+10);
ACC_map(155:175,140:160) = data_3D_abs(155:175,140:160,N3/2+10);
ACC_map = ACC_map+circshift(ACC_map, [10,10]);
fluo_map =  data_3D_abs(:,:,30)+circshift(data_3D_abs(:,:,30), [15, -45, 0]);

figure(1);
subplot(2,2,1); imagesc(calcite_map); title('calcite map'); colorbar;
subplot(2,2,2); imagesc(ACC_map); title('ACC map'); colorbar;
subplot(2,2,3); imagesc(fluo_map); title('Fluo map'); colorbar;
subplot(2,2,4); imagesc(fluo_map+ACC_map+calcite_map); title('All maps'); colorbar;

%% Définition des lois de comportement temporel et spectral

%Modélisation temporelle
time= [0:1:20];

tau_fluo = 5;
c_fluo = 0.05;
A0 = 0.05;
fluo_decay = A0*exp(-time/tau_fluo)+c_fluo;

%Modélisation spectrale
nu = [1000:1:1150];
nu_calcite = 1086;
sigma_calcite = 12;
nu_acc = 1075;
sigma_acc = 25;

spectral_behavior_calcite = (1 / (sigma_calcite * sqrt(2*pi))) * exp(-(nu-nu_calcite).^2 / (2 * sigma_calcite^2));
spectral_behavior_ACC = (1 / (sigma_acc * sqrt(2*pi))) * exp(-(nu-nu_acc).^2 / (2 * sigma_acc^2));

figure(2); clf;
subplot(2,1,1); plot(time, fluo_decay, 'k'); title('Lois de comportement temporel'); 
subplot(2,1,2); plot(nu,spectral_behavior_calcite, 'b'); hold on;
subplot(2,1,2); plot(nu, spectral_behavior_ACC, 'r'); title('Lois de comportement spectral');

%% Application des lois de comportement à l'échantillon

for k = 1:size(time,2)
       fluo_map_time(:,:,k) = fluo_map.*fluo_decay(1,k);
end;

for k = 1:size(nu,2)
       calcite_map_nu(:,:,k) = calcite_map.*spectral_behavior_calcite(1,k);
       ACC_map_nu(:,:,k) = ACC_map.*spectral_behavior_ACC(1,k);       
end;

figure(3); clf;
subplot(2,1,1);
plot(time, squeeze(fluo_map_time(91,119,:)), 'k'); title('zone fluo'); hold on;
subplot(2,1,2);
plot(nu,squeeze(calcite_map_nu(90,27,:)), 'r'); hold on;
plot(nu,squeeze(ACC_map_nu(90,27,:)), 'b'); title('zone mineral'); legend('ACC','calcite'); hold on;

%% Désalignement spatial variable (gradient diagonal)
% 
% [X, Y] = meshgrid(1:N2, 1:N1);
% 
% % normalisation entre 0 et 1
% Xn = (X - 1) / (N2 - 1);
% Yn = (Y - 1) / (N1 - 1);
% 
% % coordonnée diagonale : 0 = bas droite, 1 = haut gauche
% diag_grad = (1 - Xn + Yn) / 2;
% 
% % amplitude max du désalignement (à ajuster)
% dx_max = 10;
% dy_max = -10;
% 
% % champ de déplacement spatialement variable
% dx_map = dx_max * diag_grad;
% dy_map = dy_max * diag_grad;
% 
% % paramètres faisceaux
% x0 = N2/2;
% y0 = N1/2;
% sigma_beam = 80;
% 
% % faisceau pump (fixe)
% G_pump = exp(-((X - x0).^2 + (Y - y0).^2)/(2*sigma_beam^2));
% 
% % faisceau Stokes déformé (déplacement variable)
% G_Stokes = exp(-((X - (x0 + dx_map)).^2 + (Y - (y0 + dy_map)).^2)/(2*sigma_beam^2));
% 
% % recouvrement SRS
% SRS_overlap = G_pump .* G_Stokes;
% 
% % normalisation
% SRS_overlap = SRS_overlap / max(SRS_overlap(:));
% 
% figure;
% imagesc(SRS_overlap); colorbar;
% title('SRS overlap avec désalignement diagonal');
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Creating a set of numerical experiments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Données expérimentales
sampling_time = [1, 4, 8, 10, 15];
sampling_nu = [1086, 1044, 1075, 1065, 1044]; %number of acquisitions should be the same as number of sampling_time
bkg = 15;

for k = 1: size(sampling_time,2)
    index_time = find(sampling_time(k)==time);
    index_nu = find(sampling_nu(k)==nu);
    acquired_maps(:,:,k) =  calcite_map_nu(:,:,index_nu)+ACC_map_nu(:,:,index_nu)+fluo_map_time(:,:,index_time)+ bkg;
end;

figure(5); 
for l = 1:k
    subplot(1,k,l); imagesc(acquired_maps(:,:,l)); title([num2str(sampling_time(l)) ', ' num2str(sampling_nu(l))]); caxis([0 250]); colorbar;
end;

%% Add misalignement to acquired maps
% 
% for k = 1: size(sampling_time,2)
%     index_time = find(sampling_time(k)==time);
%     index_nu = find(sampling_nu(k)==nu);
%     signal_ideal = calcite_map_nu(:,:,index_nu) + ACC_map_nu(:,:,index_nu)+ fluo_map_time(:,:,index_time);
% 
%     % appliquer efficacité SRS uniquement sur les contributions Raman
%     signal_SRS = signal_ideal .* SRS_overlap;
% 
%     acquired_maps_misalignement(:,:,k) = signal_SRS + bkg;
% end;
% 
% figure(6); 
% for l = 1:k
%     subplot(1,k,l); imagesc(acquired_maps(:,:,l)); title([num2str(sampling_time(l)) ', ' num2str(sampling_nu(l))]); caxis([0 250]); colorbar;
% end;
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Retrieving the different mineral phases from the data set
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Fitting the fluorescence decay (manual)
A0_exp = 147; 
tau_fluo_exp = 5.1; 
c_fluo_exp = 145;

fit_fluo = A0_exp*exp(-sampling_time/tau_fluo_exp)+c_fluo_exp;

% on retire le bkg qui n'a ni composante spectrale, ni temporelle
%on choisit une zone pure fluo (ici 102,78) et une zone bkg (ici, 180, 150)
data_fluo = mean(mean(acquired_maps(102-3:102+3,78-3:78+3,:),1),2) - mean(mean(acquired_maps(180-3:180+3,150-3:150+3,:),1),2);
figure(10);clf;
plot(sampling_time, squeeze(data_fluo), '-*'); hold on;
plot(sampling_time, fit_fluo, '-r');

%% Correcting each acquisition by the expected fluo amount
sampling_time_fluo = 2;

for k = 1:size(sampling_time, 2)
    facteur_attenuation_fluo(:,:,k) = fit_fluo(1,k)/fit_fluo(1,sampling_time_fluo);
    acquired_maps_corr(:,:,k) = acquired_maps(:,:,k)-facteur_attenuation_fluo(:,:,k).*acquired_maps(:,:,sampling_time_fluo);
end

figure(11); 
for l = 1:k
    subplot(1,k,l); imagesc(acquired_maps_corr(:,:,l)); title([num2str(sampling_time(l)) ', ' num2str(sampling_nu(l))]);  colorbar;
end;

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%extracting ACC contribution
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure(12)
subplot(2,2,1); imagesc(acquired_maps_corr(:,:,1)); colorbar; title('Corrected map calcite');
subplot(2,2,2); imagesc(acquired_maps_corr(:,:,3)); colorbar; title('Corrected map ACC');
subplot(2,2,3); imagesc(acquired_maps_corr(:,:,3)-acquired_maps_corr(:,:,1)); caxis([-20 10]); colorbar; title('(ACC - Calcite) Corrected');
subplot(2,2,4); imagesc(acquired_maps(:,:,3)-acquired_maps(:,:,1)); caxis([-20 10]); colorbar; title('(ACC - Calcite) No Correction');

only_calcite = [24, 142];
only_ACC = [175, 159];
ACC_fluo = [81, 18];
calcite_fluo = [80 34];
ACC_calcite_fluo = [87 19];

figure(13); clf;
subplot(2,1,1); plot(sampling_nu, squeeze(acquired_maps_corr(only_ACC(1),only_ACC(2),:)), 'r*'); hold on;
subplot(2,1,1); plot(sampling_nu, squeeze(acquired_maps_corr(ACC_fluo(1),ACC_fluo(2),:)), 'k*'); hold on;
subplot(2,1,1); plot(sampling_nu, squeeze(acquired_maps_corr(ACC_calcite_fluo(1),ACC_calcite_fluo(2),:)), 'go'); hold on;
legend('only ACC', 'ACC on fluo', 'ACC on calcite on fluo', 'Location','northwest'); 

subplot(2,1,2); plot(sampling_nu, squeeze(acquired_maps_corr(only_calcite(1),only_calcite(2),:)), 'b*'); hold on;
subplot(2,1,2); plot(sampling_nu, 1.35*squeeze(acquired_maps_corr(calcite_fluo(1),calcite_fluo(2),:)), 'k*'); hold on;
subplot(2,1,2); plot(sampling_nu, 0.52*squeeze(acquired_maps_corr(ACC_calcite_fluo(1),ACC_calcite_fluo(2),:)), 'mo'); hold on;

legend('only calcite', 'calcite on fluo', 'ACC on calcite on fluo', 'Location','northwest'); 





