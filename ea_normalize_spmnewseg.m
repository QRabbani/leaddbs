function varargout=ea_normalize_spmnewseg(options)
% This is a function that normalizes both a copy of transversal and coronar
% images into MNI-space. The goal was to make the procedure both robust and
% automatic, but still, it must be said that normalization results should
% be taken with much care because all reconstruction results heavily depend
% on these results. Normalization of DBS-MR-images is especially
% problematic since usually, the field of view doesn't cover the whole
% brain (to reduce SAR-levels during acquisition) and since electrode
% artifacts can impair the normalization process. Therefore, normalization
% might be best archieved with other tools that have specialized on
% normalization of such image data.
%
% The procedure used here uses the SPM "Segment" routine and
% is probably the most straight-forward way using SPM.
%
% The function uses some code snippets written by Ged Ridgway.
% __________________________________________________________________________________
% Copyright (C) 2014 Charite University Medicine Berlin, Movement Disorders Unit
% Andreas Horn

if ischar(options) % return name of method.
    varargout{1}='SPM New Segment nonlinear';
    return
end



if exist([options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,'.gz'],'file')
    try
        gunzip([options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,'.gz']);
    end
    try
        gunzip([options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized,'.gz']);
    end
    try
        gunzip([options.root,options.prefs.patientdir,filesep,options.prefs.sagnii_unnormalized,'.gz']);
    end
    
    
    try
        gunzip([options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,'.gz']);
    end
end

% check if backup files exist, if not backup

if ~exist([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.tranii_unnormalized],'file')
    copyfile([options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized],[options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.tranii_unnormalized]);
else
    copyfile([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.tranii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized]);
end
if ~exist([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.cornii_unnormalized],'file')
    try    copyfile([options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized],[options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.cornii_unnormalized]); end
else
    try    copyfile([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.cornii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized]); end
end
if ~exist([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.sagnii_unnormalized],'file')
    try    copyfile([options.root,options.prefs.patientdir,filesep,options.prefs.sagnii_unnormalized],[options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.sagnii_unnormalized]); end
else
    try    copyfile([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.sagnii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.sagnii_unnormalized]); end
end



% First, do the coreg part:

ea_coreg(options,options.prefs.normalize.coreg);






% now segment the preoperative version.

disp('Segmenting preoperative version.');
load([options.earoot,'ext_libs',filesep,'segment',filesep,'segjob']);
job.channel.vols{1}=[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized];
for tpm=1:6
    job.tissue(tpm).tpm=fullfile(fileparts(which('spm')),'toolbox','Seg',['TPM.nii,',num2str(tpm)]);
    if tpm<4
        job.tissue(tpm).native=[0,0];
    else
        job.tissue(tpm).native=[0,0];
    end
end


ea_spm_preproc_run(job); % exactly the same as the SPM version ("New Segment" in SPM8) but with an increase in resolution to 0.5 mm iso.


disp('*** Segmentation of preoperative MRI done.');

keyboard


% export normalization parameters:
for inverse=0:1
    if inverse
        addstr='_inv';
    else
        addstr='';
    end
    matlabbatch{1}.spm.util.defs.comp{1}.dartel.flowfield = {[options.root,options.prefs.patientdir,filesep,'u_rc1',options.prefs.prenii_unnormalized]};
    matlabbatch{1}.spm.util.defs.comp{1}.dartel.times = [1-inverse 0+inverse];
    matlabbatch{1}.spm.util.defs.comp{1}.dartel.K = 6;
    matlabbatch{1}.spm.util.defs.ofname = ['ea',addstr,'_normparams'];
    matlabbatch{1}.spm.util.defs.fnames = '';
    matlabbatch{1}.spm.util.defs.savedir.saveusr = {[options.root,options.prefs.patientdir,filesep]};
    matlabbatch{1}.spm.util.defs.interp = 1;
    jobs{1}=matlabbatch;
    
    cfg_util('run',jobs);
    disp('*** Exported normalization parameters to y_ea_normparams.nii');
    clear matlabbatch jobs;
end



% apply estimated transformations to pre-operative versions.


[~,nm]=fileparts(options.prefs.prenii_unnormalized); % cut off file extension

voxi=[0.22 0.22 0.5]; % export highres
bbi=[-55 45 9.5; 55 -65 -25]; % with small bounding box
matlabbatch{1}.spm.util.defs.comp{1}.sn2def.matname = {[options.root,options.prefs.patientdir,filesep,nm,'_seg_sn.mat']};
matlabbatch{1}.spm.util.defs.comp{1}.sn2def.vox = voxi;
matlabbatch{1}.spm.util.defs.comp{1}.sn2def.bb = bbi;

matlabbatch{1}.spm.util.defs.ofname = 'ea_normparams';
try
    matlabbatch{1}.spm.util.defs.fnames = [{[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,',1']},finas];
catch % CT
    matlabbatch{1}.spm.util.defs.fnames = {[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,',1']};
end
matlabbatch{1}.spm.util.defs.savedir.saveusr = {[options.root,options.prefs.patientdir,filesep]};
matlabbatch{1}.spm.util.defs.interp = 6;

jobs{1}=matlabbatch;
cfg_util('run',jobs);
clear matlabbatch jobs;




% write out transformation matrix

T{1}=load([options.root,options.prefs.patientdir,filesep,nm,'_seg_sn.mat']);
T{1}.M = T{1}.VG(1).mat*inv(T{1}.Affine)*inv(T{1}.VF(1).mat); % get mmM that transforms from mm to mm space.
T{1}.VFM=worldmat2flirtmat(T{1}.M,[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized]);

FLIRTMAT=T{1}.VFM;
M=T{1}.M;





% Save transformation for later use in FLIRT
flirtmat_write([options.root,options.prefs.patientdir,filesep,'flirt_transform'],FLIRTMAT);

mmFLIRT=flirtmat2worldmat(FLIRTMAT,[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized],[options.root,options.prefs.patientdir,filesep,'w',options.prefs.tranii_unnormalized]);
flirtmat_write([options.root,options.prefs.patientdir,filesep,'mmflirt_transform'],mmFLIRT);
% Save transformation matrix M that maps from mm space in native acquisition to mm space in MNI space.
save([options.root,options.prefs.patientdir,filesep,'ea_normparams'],'T','M');


% make normalization "permanent" and include correct bounding box.




for export=2:4
    switch export
        case 2
            outf=options.prefs.tranii;
            fina=[options.root,options.prefs.patientdir,filesep,'w',options.prefs.tranii_unnormalized,',1'];
        case 3
            outf=options.prefs.cornii;
            fina=[options.root,options.prefs.patientdir,filesep,'w',options.prefs.cornii_unnormalized,',1'];
        case 4
            outf=options.prefs.sagnii;
            fina=[options.root,options.prefs.patientdir,filesep,'w',options.prefs.sagnii_unnormalized,',1'];
    end
    
    % save a backup
    
    if exist([options.root,options.prefs.patientdir,filesep,outf],'file')
        movefile([options.root,options.prefs.patientdir,filesep,outf],[options.root,options.prefs.patientdir,filesep,'ea_backup',date,num2str(now),outf]);
    end
    
    matlabbatch{1}.spm.util.imcalc.input = {[options.earoot,'templates',filesep,'bb.nii,1']
        fina
        };
    matlabbatch{1}.spm.util.imcalc.output = outf;
    matlabbatch{1}.spm.util.imcalc.outdir = {[options.root,options.prefs.patientdir,filesep]};
    matlabbatch{1}.spm.util.imcalc.expression = ['i2'];
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
    jobs{1}=matlabbatch;
    try
        cfg_util('run',jobs);
    end
    clear matlabbatch jobs;
end

% build global versions of files



[~,nm]=fileparts(options.prefs.prenii_unnormalized); % cut off file extension

voxi=[0.5 0.5 0.5]; % export highres
bbi=nan(2,3);
matlabbatch{1}.spm.util.defs.comp{1}.sn2def.matname = {[options.root,options.prefs.patientdir,filesep,nm,'_seg_sn.mat']};
matlabbatch{1}.spm.util.defs.comp{1}.sn2def.vox = voxi;
matlabbatch{1}.spm.util.defs.comp{1}.sn2def.bb = bbi;

matlabbatch{1}.spm.util.defs.ofname = 'ea_normparams';
try
    matlabbatch{1}.spm.util.defs.fnames = [{[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1'],[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,',1']},finas];
catch
    matlabbatch{1}.spm.util.defs.fnames = {[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1'],[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,',1']};
end
matlabbatch{1}.spm.util.defs.savedir.saveusr = {[options.root,options.prefs.patientdir,filesep]};
matlabbatch{1}.spm.util.defs.interp = 6;

jobs{1}=matlabbatch;
cfg_util('run',jobs);
clear matlabbatch jobs;


% export (generalized) normalization parameters:
for inverse=0:1
    if inverse
        addstr='_inv';
    else
        addstr='';
    end
    matlabbatch{1}.spm.util.defs.comp{1}.sn2def.matname = {[options.root,options.prefs.patientdir,filesep,nm,'_seg',addstr,'_sn.mat']};
    matlabbatch{1}.spm.util.defs.comp{1}.sn2def.vox = [0.5 0.5 0.5];
    matlabbatch{1}.spm.util.defs.comp{1}.sn2def.bb = nan(2,3);
    matlabbatch{1}.spm.util.defs.ofname = ['ea',addstr,'_normparams'];
    matlabbatch{1}.spm.util.defs.fnames = '';
    matlabbatch{1}.spm.util.defs.savedir.saveusr = {[options.root,options.prefs.patientdir,filesep]};
    matlabbatch{1}.spm.util.defs.interp = 1;
    jobs{1}=matlabbatch;
    
    cfg_util('run',jobs);
    disp('*** Exported normalization parameters to y_ea_normparams.nii');
    clear matlabbatch jobs;
end



movefile([options.root,options.prefs.patientdir,filesep,'w',options.prefs.tranii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.gtranii]);
try movefile([options.root,options.prefs.patientdir,filesep,'w',options.prefs.cornii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.gcornii]); end
try movefile([options.root,options.prefs.patientdir,filesep,'w',options.prefs.sagnii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.gsagnii]); end


% restore original files (from coregistration)
copyfile([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.tranii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized]);
try    copyfile([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.cornii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized]); end
try    copyfile([options.root,options.prefs.patientdir,filesep,'backup_',options.prefs.sagnii_unnormalized],[options.root,options.prefs.patientdir,filesep,options.prefs.sagnii_unnormalized]); end




function [flirtmat spmvoxmat fslvoxmat] = worldmat2flirtmat(worldmat, src, trg)
%worldmat2flirtmat: convert NIfTI world (mm) coordinates matrix to flirt
%
% Example:
%  [flirtmat spmvoxmat fslvoxmat] = worldmat2flirtdmat(worldmat, src, trg);
%
% See also: flirtmat2worldmat, flirtmat_write

% Copyright 2009 Ged Ridgway <ged.ridgway gmail.com>

if ischar(src)
    src = nifti(src);
end
if ischar(trg)
    trg = nifti(trg);
end

spmvoxmat = inv(src.mat) * worldmat * trg.mat;
addone = eye(4); addone(:, 4) = 1;
fslvoxmat = inv(addone) * spmvoxmat * addone;
trgscl = nifti2scl(trg);
srcscl = nifti2scl(src);
flirtmat = inv( srcscl * fslvoxmat * inv(trgscl) );



function flirtmat_write(fname, mat)
%flirtmat_write: save a 4-by-4 matrix to a file as handled by flirt -init
% Example:
%  flirtmat_write(fname, affinemat)
% See also: flirtmat_read, flirtmat2worldmat, worldmat2flirtmat

% Copyright 2009 Ged Ridgway <ged.ridgway gmail.com>

fid = fopen(fname, 'w');
% Note that transpose is needed to go from MATLAB's column-major matrix to
% writing the file in a row-major way (see also flirtmat_read)
str = sprintf('%f  %f  %f  %f\n', mat');
fprintf(fid, str(1:end-1)); % drop final newline
fclose(fid);




function [worldmat spmvoxmat fslvoxmat] = flirtmat2worldmat(flirtmat, src, trg)
%flirtmat2worldmat: convert saved flirt matrix to NIfTI world coords matrix
% flirt matrix is from text file specified in "flirt -omat mat.txt" command
% world matrix maps from NIfTI world coordinates in target to source. Note:
% mat.txt contains a mapping from source to target in FSL's *scaled* coords
% which are not NIfTI world coordinates, and note src-trg directionality!
% worldmat from this script reproduces "img2imgcoord -mm ...".
%
% The script can also return a matrix to map from target to source voxels
% in MATLAB/SPM's one-based convention, or in FSL's zero-based convention
%
% Example:
%  [worldmat spmvoxmat fslvoxmat] = flirtmat2worldmat(flirtmat, src, trg);
%
% See also: worldmat2flirtmat, flirtmat_read, flirtmat_write

% Copyright 2009 Ged Ridgway <ged.ridgway gmail.com>

if ischar(src)
    src = nifti(src);
end
if ischar(trg)
    trg = nifti(trg);
end

if ischar(flirtmat)
    flirtmat = flirtmat_read(flirtmat);
end

% src = inv(flirtmat) * trg
% srcvox = src.mat \ inv(flirtmat) * trg.mat * trgvox
% BUT, flirt doesn't use src.mat, only absolute values of the
% scaling elements from it,
% AND, if images are not radiological, the x-axis is flipped, see:
%  https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind0810&L=FSL&P=185638
%  https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind0903&L=FSL&P=R93775
trgscl = nifti2scl(trg);
srcscl = nifti2scl(src);
fslvoxmat = inv(srcscl) * inv(flirtmat) * trgscl;

% AND, Flirt's voxels are zero-based, while SPM's are one-based...
addone = eye(4); addone(:, 4) = 1;
spmvoxmat = addone * fslvoxmat * inv(addone);

worldmat = src.mat * spmvoxmat * inv(trg.mat);


%%
function scl = nifti2scl(N)
% not sure if this is always correct with rotations in mat, but seems okay!
scl = diag([sqrt(sum(N.mat(1:3,1:3).^2)) 1]);
if det(N.mat) > 0
    % neurological, x-axis is flipped, such that [3 2 1 0] and [0 1 2 3]
    % have the same *scaled* coordinates:
    xflip = diag([-1 1 1 1]);
    xflip(1, 4) = N.dat.dim(1)-1; % reflect about centre
    scl = scl * xflip;
end
