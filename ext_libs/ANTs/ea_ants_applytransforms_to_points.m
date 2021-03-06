function output=ea_ants_applytransforms_to_points(varargin)
% Wrapper for antsApplyTransformsToPoints

subdir=varargin{1};
input=varargin{2};
useinverse=varargin{3};
if useinverse
    istr='Inverse';
else
    istr='';
end

[~,ptname]=fileparts(subdir);
options.prefs=ea_prefs(ptname);


[~,glprebase]=fileparts(options.prefs.gprenii);
[~,lprebase]=fileparts(options.prefs.prenii);
% use 'gl' affix for tranforms
try
    if exist([subdir,lprebase,'Composite.h5'],'file')
        movefile([subdir,lprebase,'Composite.h5'],[subdir,glprebase,'Composite.h5']);
        movefile([subdir,lprebase,'InverseComposite.h5'],[subdir,glprebase,'InverseComposite.h5']);
    end
end
try
    if exist([subdir,lprebase,'0GenericAffine.mat'],'file')
        movefile([subdir,lprebase,'0GenericAffine.mat'],[subdir,glprebase,'0GenericAffine.mat']);
        try movefile([subdir,lprebase,'1Warp.nii.gz'],[subdir,glprebase,'1Warp.nii.gz']); end
        try movefile([subdir,lprebase,'1InverseWarp.nii.gz'],[subdir,glprebase,'1InverseWarp.nii.gz']); end
    end
end

if nargin>3
    transform=varargin{4};
    tstring=[' --transform [',transform, ',',num2str(useinverse),']']; % [transformFileName,useInverse]
else
    if useinverse
        if exist([subdir,glprebase,'Composite.h5'],'file')
            tstring=[' -t [',ea_path_helper([subdir,glprebase]),istr,'Composite.h5,0]'];
        else
            tstring=    [  ' -t [',ea_path_helper([subdir,glprebase]),'0GenericAffine.mat,',num2str(useinverse),']',...
                ' -t [',ea_path_helper([subdir,glprebase]),'1',istr,'Warp.nii.gz,',num2str(0),']',...
                ];
        end

    else
        if exist([subdir,glprebase,'Composite.h5'],'file')
            tstring=[' -t [',ea_path_helper([subdir,glprebase]),istr,'Composite.h5,0]'];
        else
            tstring=[' -t [',ea_path_helper([subdir,glprebase]),'1',istr,'Warp.nii.gz,',num2str(0),']',...
                ' -t [',ea_path_helper([subdir,glprebase]),'0GenericAffine.mat,',num2str(useinverse),']'...
                ];
        end
    end
end

ea_libs_helper;

basedir = [fileparts(mfilename('fullpath')), filesep];

if ispc
    applyTransformsToPoints = [basedir, 'antsApplyTransformsToPoints.exe'];
else
    applyTransformsToPoints = [basedir, 'antsApplyTransformsToPoints.', computer('arch')];
end

    guid=ea_generate_guid;

cmd = [applyTransformsToPoints, ...
    ' --dimensionality 3' ...   % dimensionality
    ' --precision 1' ...    % double precision
    ' --input ', ea_path_helper([subdir,'tmpin_',guid,'.csv']) ...  % input csv file with x,y,z,t (at least) as the column header
    ' --output ', ea_path_helper([subdir,'tmpout_',guid,'.csv']) ...    % warped output csv file
tstring];



ea_writecsv([subdir,'tmpin_',guid,'.csv'],input);

if ~ispc
    system(['bash -c "', cmd, '"']);
else
    system(cmd);
end

output=ea_readcsv([subdir,'tmpout_',guid,'.csv']);
delete([subdir,'tmpout_',guid,'.csv']);
delete([subdir,'tmpin_',guid,'.csv']);


function coord=ea_readcsv(pth)
fid=fopen(pth);

C=textscan(fid,'%f %f %f %f','commentStyle', '#','delimiter', ',','Headerlines',1);
fclose(fid);
coord=cell2mat(C(1:3));


function ea_writecsv(pth,input)
fid=fopen(pth,'w');
try
fprintf(fid,'x,y,z,t \n');
catch
    ea_error(['Cannot open file for writing at ',pth,'.']);
end
fprintf(fid,'%f,%f,%f,0\n',input');
fclose(fid);
