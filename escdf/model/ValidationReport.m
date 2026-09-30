classdef ValidationReport
% VALIDATIONREPORT Structured validation result for one dataset.
%
% A ValidationReport stores the machine-readable result of validating one
% dataset against a resolved ESCDF specification.
%
% Parameters
% ----------
% checked_specification : char
%     Name of the resolved specification used for validation.
% Optional name/value arguments:
%   'resolved_specification'
%       ResolvedSpecification object used during validation.
%
% Notes
% -----
% This report is intended to be both machine-readable and suitable for
% human-readable summarization.
%
% See Also
% --------
% Validation
% ResolvedSpecification

    properties
        checked_specification
        resolved_specification

        is_valid

        missing_properties
        invalid_choices
        ambiguous_choices
        bad_types
        bad_ranks
        bad_sizes
        inconsistent_dimensions
        invalid_enumerations
        invalid_regexes
        invalid_value_constraints
        constraint_failures
        modified_property_failures
        warnings

        valid_choice_branches
        bound_dimensions
        present_properties
    end

    methods
        function obj = ValidationReport(checked_specification, varargin)
        % Create a structured validation report.
        %
        % Parameters
        % ----------
        % checked_specification : char
        %     Name of the resolved specification used for validation.
        % Optional name/value arguments:
        %   'resolved_specification'
        %       ResolvedSpecification object used during validation.
            p = inputParser;
            addParameter(p, 'resolved_specification', []);
            parse(p, varargin{:});

            obj.checked_specification = char(string(checked_specification));
            obj.resolved_specification = p.Results.resolved_specification;

            obj.is_valid = true;

            obj.missing_properties = {};
            obj.invalid_choices = {};
            obj.ambiguous_choices = {};
            obj.bad_types = {};
            obj.bad_ranks = {};
            obj.bad_sizes = {};
            obj.inconsistent_dimensions = {};
            obj.invalid_enumerations = {};
            obj.invalid_regexes = {};
            obj.invalid_value_constraints = {};
            obj.constraint_failures = {};
            obj.modified_property_failures = {};
            obj.warnings = {};

            obj.valid_choice_branches = containers.Map();
            obj.bound_dimensions = containers.Map();
            obj.present_properties = {};
        end

        function lines = summary_lines(obj)
        % Build a human-readable summary of validation failures.
        %
        % Returns
        % -------
        % lines : cell array of char
        %     Human-readable summary lines.
            lines = {};

            for i = 1:length(obj.missing_properties)
                item = obj.missing_properties{i};
                lines{end+1} = sprintf('Required property %s is missing.', item.property_name); %#ok<AGROW>
            end

            for i = 1:length(obj.bad_types)
                item = obj.bad_types{i};
                lines{end+1} = sprintf( ...
                    'Property %s has datatype %s but expected %s.', ...
                    item.property_name, item.actual_type, item.expected_type); %#ok<AGROW>
            end

            for i = 1:length(obj.bad_ranks)
                item = obj.bad_ranks{i};
                lines{end+1} = sprintf( ...
                    'Property %s has rank %d but expected rank %d.', ...
                    item.property_name, item.actual_rank, item.expected_rank); %#ok<AGROW>
            end

            for i = 1:length(obj.bad_sizes)
                item = obj.bad_sizes{i};
                lines{end+1} = sprintf( ...
                    'Property %s dimension %d has size %d but expected %d.', ...
                    item.property_name, item.dimension_index, ...
                    item.actual_size, item.expected_size); %#ok<AGROW>
            end

            for i = 1:length(obj.invalid_choices)
                item = obj.invalid_choices{i};
                lines{end+1} = sprintf( ...
                    'Choice group %s has no valid branch.', ...
                    item.choice_group); %#ok<AGROW>
            end

            for i = 1:length(obj.ambiguous_choices)
                item = obj.ambiguous_choices{i};
                lines{end+1} = sprintf( ...
                    'Choice group %s has multiple valid branches: %s.', ...
                    item.choice_group, strjoin(item.valid_branches, ', ')); %#ok<AGROW>
            end

            for i = 1:length(obj.invalid_enumerations)
                item = obj.invalid_enumerations{i};
                bad_values_str = strjoin(cellfun(@ValidationReport.scalar_to_string, ...
                    item.bad_values, 'UniformOutput', false), ', ');
                valid_values_str = strjoin(item.valid_values, ', ');
                lines{end+1} = sprintf( ...
                    'Property %s has invalid values %s. Allowed values are %s.', ...
                    item.property_name, bad_values_str, valid_values_str); %#ok<AGROW>
            end

            for i = 1:length(obj.invalid_regexes)
                item = obj.invalid_regexes{i};
                bad_values_str = strjoin(cellfun(@ValidationReport.scalar_to_string, ...
                    item.bad_values, 'UniformOutput', false), ', ');
                lines{end+1} = sprintf( ...
                    'Property %s has invalid values %s.', ...
                    item.property_name, bad_values_str); %#ok<AGROW>
            end

            for i = 1:length(obj.inconsistent_dimensions)
                item = obj.inconsistent_dimensions{i};
                lines{end+1} = sprintf( ...
                    'Dimension %s is inconsistent across properties.', ...
                    item.dimension_name); %#ok<AGROW>
                bindings = item.bindings;
                for j = 1:length(bindings)
                    binding = bindings{j};
                    lines{end+1} = sprintf('  %s: %d', binding.property_name, binding.size); %#ok<AGROW>
                end
            end

            for i = 1:length(obj.modified_property_failures)
                item = obj.modified_property_failures{i};
                lines{end+1} = item.message; %#ok<AGROW>
            end

            for i = 1:length(obj.invalid_value_constraints)
                item = obj.invalid_value_constraints{i};
                lines{end+1} = item.message; %#ok<AGROW>
            end

            for i = 1:length(obj.constraint_failures)
                item = obj.constraint_failures{i};
                lines{end+1} = item.message; %#ok<AGROW>
            end

            for i = 1:length(obj.warnings)
                lines{end+1} = ['Warning: ', obj.warnings{i}]; %#ok<AGROW>
            end
        end

        function out = summary(obj)
        % Build a human-readable summary string.
        %
        % Returns
        % -------
        % out : char
        %     Human-readable summary text.
            lines = obj.summary_lines();
            out = strjoin(lines, newline);
        end

        function disp(obj)
        % Display a validation summary.
            fprintf('%s\n', obj.summary());
        end
    end

    methods (Static, Access=private)
        function out = scalar_to_string(value)
            if isstring(value)
                out = char(value);
            elseif ischar(value)
                out = value;
            elseif isnumeric(value) || islogical(value)
                out = num2str(value);
            else
                out = char(string(value));
            end
        end
    end
end