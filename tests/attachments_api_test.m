classdef attachments_api_test < matlab.unittest.TestCase

    properties
        temp_folder
        original_path
        source_folder
    end

    methods (TestMethodSetup)
        function setupEnvironment(testCase)
            current_file_folder = fileparts(mfilename('fullpath'));
            testCase.source_folder = fullfile(current_file_folder, '..', 'escdf');
            testCase.temp_folder = tempname;
            testCase.original_path = addpath(testCase.source_folder);
            mkdir(testCase.temp_folder);
        end
    end

    methods (TestMethodTeardown)
        function teardownEnvironment(testCase)
            if isfolder(testCase.temp_folder)
                rmdir(testCase.temp_folder, 's');
            end
            path(testCase.original_path);
        end
    end

    methods (Test)
        function test_set_and_extract_attachments_roundtrip(testCase)
            src1 = fullfile(testCase.temp_folder, 'hello.bin');
            src2 = fullfile(testCase.temp_folder, 'numbers.bin');

            fid = fopen(src1, 'w');
            fwrite(fid, uint8('hello world'));
            fclose(fid);

            fid = fopen(src2, 'w');
            fwrite(fid, uint8([1;2;3;4;5;255]));
            fclose(fid);

            md = escdf_dataset( ...
                'global_meta_with_attachments', ...
                'global_test_attributes', ...
                'Global metadata with attachments');

            md.test_name = {'Attachment Test'};
            md.program = {'Program Bytes'};
            md.hardware_list = {'hardware_1'};
            md.point_of_contact = {'person_1'};
            md.set_attachments({src1, src2});

            testCase.verifyTrue(md.validate());

            f = escdf();
            f.add_metadata(md);

            escdf_path = fullfile(testCase.temp_folder, 'attachments_roundtrip.h5');
            f.write_to_disk(escdf_path, true);

            loaded = escdf.load(escdf_path);
            loaded_md = loaded.get_metadata('global_meta_with_attachments');

            outdir = fullfile(testCase.temp_folder, 'extracted');
            mkdir(outdir);
            loaded_md.dump_attachments_to_disk(outdir);

            hello_out = fullfile(outdir, 'hello.bin');
            numbers_out = fullfile(outdir, 'numbers.bin');

            testCase.verifyTrue(isfile(hello_out));
            testCase.verifyTrue(isfile(numbers_out));

            fid = fopen(hello_out, 'r');
            hello_bytes = fread(fid, inf, '*uint8');
            fclose(fid);

            fid = fopen(numbers_out, 'r');
            numbers_bytes = fread(fid, inf, '*uint8');
            fclose(fid);

            testCase.verifyEqual(hello_bytes(:), uint8('hello world').');
            testCase.verifyEqual(numbers_bytes(:), uint8([1;2;3;4;5;255]));

            testCase.verifyEqual(loaded_md.attachment_names(:), {'hello.bin'; 'numbers.bin'});
        end

        function test_list_attachment_names_returns_all_names(testCase)
            src1 = fullfile(testCase.temp_folder, 'hello.bin');
            src2 = fullfile(testCase.temp_folder, 'numbers.bin');

            fid = fopen(src1, 'w');
            fwrite(fid, uint8('hello world'));
            fclose(fid);

            fid = fopen(src2, 'w');
            fwrite(fid, uint8([1 2 3 4 5 255]));
            fclose(fid);

            md = escdf_dataset('global_meta_with_attachments', 'global_test_attributes');
            md.test_name = {'test program name'};
            md.program = {'program abc'};
            md.hardware_list = {'instr 1'; 'instr 2'};
            md.point_of_contact = {'tom'; 'jerry'};
            md.set_attachments({src1, src2});

            testCase.verifyEqual(md.list_attachment_names(), {'hello.bin'; 'numbers.bin'});
        end

        function test_get_attachment_index_returns_expected_index(testCase)
            src1 = fullfile(testCase.temp_folder, 'hello.bin');
            src2 = fullfile(testCase.temp_folder, 'numbers.bin');

            fid = fopen(src1, 'w');
            fwrite(fid, uint8('hello world'));
            fclose(fid);

            fid = fopen(src2, 'w');
            fwrite(fid, uint8([1 2 3 4 5 255]));
            fclose(fid);

            md = escdf_dataset('global_meta_with_attachments', 'global_test_attributes');
            md.test_name = {'test program name'};
            md.program = {'program abc'};
            md.hardware_list = {'instr 1'; 'instr 2'};
            md.point_of_contact = {'tom'; 'jerry'};
            md.set_attachments({src1, src2});

            testCase.verifyEqual(md.get_attachment_index('hello.bin'), 1);
            testCase.verifyEqual(md.get_attachment_index('numbers.bin'), 2);
        end

        function test_get_attachment_index_raises_for_missing_name(testCase)
            src1 = fullfile(testCase.temp_folder, 'hello.bin');

            fid = fopen(src1, 'w');
            fwrite(fid, uint8('hello world'));
            fclose(fid);

            md = escdf_dataset('global_meta_with_attachments', 'global_test_attributes');
            md.test_name = {'test program name'};
            md.program = {'program abc'};
            md.hardware_list = {'instr 1'; 'instr 2'};
            md.point_of_contact = {'tom'; 'jerry'};
            md.set_attachments({src1});

            did_error = false;
            try
                md.get_attachment_index('missing.bin');
            catch
                did_error = true;
            end
            testCase.verifyTrue(did_error);
        end

        function test_dump_attachment_to_disk_writes_single_attachment(testCase)
            src1 = fullfile(testCase.temp_folder, 'hello.bin');
            src2 = fullfile(testCase.temp_folder, 'numbers.bin');

            fid = fopen(src1, 'w');
            fwrite(fid, uint8('hello world'));
            fclose(fid);

            fid = fopen(src2, 'w');
            fwrite(fid, uint8([1 2 3 4 5 255]));
            fclose(fid);

            md = escdf_dataset('global_meta_with_attachments', 'global_test_attributes');
            md.test_name = {'test program name'};
            md.program = {'program abc'};
            md.hardware_list = {'instr 1'; 'instr 2'};
            md.point_of_contact = {'tom'; 'jerry'};
            md.set_attachments({src1, src2});

            outdir = fullfile(testCase.temp_folder, 'single_extract');
            mkdir(outdir);

            md.dump_attachment_to_disk('numbers.bin', outdir);

            hello_out = fullfile(outdir, 'hello.bin');
            numbers_out = fullfile(outdir, 'numbers.bin');

            testCase.verifyFalse(isfile(hello_out));
            testCase.verifyTrue(isfile(numbers_out));

            fid = fopen(numbers_out, 'r');
            numbers_bytes = fread(fid, inf, '*uint8');
            fclose(fid);

            testCase.verifyEqual(numbers_bytes, uint8([1 2 3 4 5 255]).');
        end

    end
end