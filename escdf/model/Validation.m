classdef Validation
% VALIDATION Canonical dataset validation against resolved specifications.
%
% This class provides static helper methods for validating datasets
% directly against the canonical ESCDF specification model.
%
% Notes
% -----
% This first-pass canonical validator currently checks:
%
% - required standalone property presence
% - property datatype compatibility
% - property rank compatibility
% - fixed-dimension size compatibility
% - symbolic dimension consistency
% - choice-group validity
% - enumeration membership
% - regex conformance
% - modified-property invalidation
%
% Cross-property ConstraintRule evaluation and value-constraint
% evaluation are reserved for later passes.
%
% See Also
% --------
% ValidationReport
% ResolvedSpecification
% escdf_dataset

    methods (Static)
        function report = validate_dataset_against_resolved_specification(dataset, resolved_specification, hide_issues)
        % Validate a dataset against a resolved canonical specification.
        %
        % Parameters
        % ----------
        % dataset : escdf_dataset
        %     Dataset object to validate.
        % resolved_specification : ResolvedSpecification
        %     Effective canonical specification used for validation.
        % hide_issues : logical, optional
        %     If true, suppress printed issue summaries.
        %
        % Returns
        % -------
        % report : ValidationReport
        %     Structured validation result.
            if nargin < 3
                hide_issues = false;
            end

            report = ValidationReport( ...
                resolved_specification.name, ...
                'resolved_specification', resolved_specification);

            present_properties = Validation.get_present_property_names(...
                dataset, resolved_specification);
            report.present_properties = sort(present_properties);

            dimension_bindings = containers.Map();

            % ----------------------------------------------------------
            % Standalone properties
            % ----------------------------------------------------------
            for i = 1:length(resolved_specification.standalone_properties)
                property_definition = resolved_specification.standalone_properties(i);
                property_name = property_definition.name;
                property_value = dataset.(property_name);

                if isempty(property_value)
                    if ~property_definition.optional
                        report.missing_properties{end+1} = struct( ...
                            'property_name', property_name); %#ok<AGROW>
                        report.is_valid = false;
                    end
                    continue
                end

                [declaration_valid, report, dimension_bindings] = ...
                    Validation.validate_present_property_against_definition( ...
                        property_value, property_definition, report, dimension_bindings);

                if ~declaration_valid
                    report.is_valid = false;
                end
            end

            % ----------------------------------------------------------
            % Choice groups
            % ----------------------------------------------------------
            choice_group_names = keys(resolved_specification.choice_groups);
            for i = 1:length(choice_group_names)
                choice_group_name = choice_group_names{i};
                branch_map = resolved_specification.choice_groups(choice_group_name);
                branch_names = keys(branch_map);

                valid_branches = {};
                valid_branch_dimension_updates = containers.Map();

                for j = 1:length(branch_names)
                    branch_name = branch_names{j};
                    branch_definitions = branch_map(branch_name);

                    [branch_ok, branch_dimension_updates] = ...
                        Validation.validate_choice_branch( ...
                            dataset, branch_definitions, report, false);

                    if branch_ok
                        valid_branches{end+1} = branch_name; %#ok<AGROW>
                        valid_branch_dimension_updates(branch_name) = branch_dimension_updates;
                    end
                end

                if isempty(valid_branches)
                    report.invalid_choices{end+1} = struct( ...
                        'choice_group', choice_group_name, ...
                        'valid_branches', {{}});
                    report.is_valid = false;

                elseif length(valid_branches) > 1
                    report.ambiguous_choices{end+1} = struct( ...
                        'choice_group', choice_group_name, ...
                        'valid_branches', {valid_branches});
                    report.is_valid = false;

                else
                    chosen_branch_name = valid_branches{1};
                    chosen_branch_definitions = branch_map(chosen_branch_name);

                    report.valid_choice_branches(choice_group_name) = {chosen_branch_name};

                    [branch_ok, branch_dimension_updates, report] = ...
                        Validation.validate_choice_branch_collecting( ...
                            dataset, chosen_branch_definitions, report);

                    if ~branch_ok
                        report.is_valid = false;
                    end

                    dimension_bindings = Validation.merge_dimension_bindings( ...
                        dimension_bindings, branch_dimension_updates);
                end
            end

            % ----------------------------------------------------------
            % Dimension consistency
            % ----------------------------------------------------------
            inconsistent_dimensions = Validation.find_inconsistent_dimensions(dimension_bindings);
            if ~isempty(inconsistent_dimensions)
                report.inconsistent_dimensions = [report.inconsistent_dimensions, inconsistent_dimensions];
                report.is_valid = false;
            end

            report.bound_dimensions = Validation.collapse_dimension_bindings(dimension_bindings);

            % ----------------------------------------------------------
            % Cross-property relational constraints
            % ----------------------------------------------------------
            constraint_failures = Validation.evaluate_constraint_rules( ...
                dataset, resolved_specification, present_properties);
            if ~isempty(constraint_failures)
                report.constraint_failures = [report.constraint_failures, constraint_failures];
                report.is_valid = false;
            end

            % ----------------------------------------------------------
            % Dataset-level policy checks
            % ----------------------------------------------------------
            if dataset.get_has_modified_properties()
                report.modified_property_failures{end+1} = struct( ...
                    'message', 'Dataset has modified properties and therefore cannot be valid.');
                report.is_valid = false;
            end

            if ~hide_issues && ~report.is_valid
                summary = report.summary();
                if ~isempty(summary)
                    disp(summary)
                end
            end
        end
    end

    methods (Static, Access=private)
        function present = get_present_property_names(dataset, resolved_specification)
        % Return names of properties that are present on a dataset.
        %
        % Parameters
        % ----------
        % dataset : escdf_dataset
        %     Dataset object.
        % resolved_specification : ResolvedSpecification
        %     Effective resolved specification describing valid property
        %     names.
        %
        % Returns
        % -------
        % present : cell array of char
        %     Property names whose values are not empty.
            property_names = resolved_specification.property_names;
            present = {};
            for i = 1:length(property_names)
                property_name = property_names{i};
                if ~isempty(dataset.(property_name))
                    present{end+1} = property_name; %#ok<AGROW>
                end
            end
        end

        function [property_ok, report, dimension_bindings] = ...
                validate_present_property_against_definition( ...
                    property_value, property_definition, report, dimension_bindings)
            property_ok = true;
            property_name = property_definition.name;

            if ~strcmp(property_value.get_format(), property_definition.datatype)
                report.bad_types{end+1} = struct( ...
                    'property_name', property_name, ...
                    'actual_type', property_value.get_format(), ...
                    'expected_type', property_definition.datatype); %#ok<AGROW>
                property_ok = false;
                return
            end

            actual_shape = property_value.get_size();
            expected_rank = length(property_definition.shape);
            actual_rank = length(actual_shape);

            if actual_rank ~= expected_rank
                report.bad_ranks{end+1} = struct( ...
                    'property_name', property_name, ...
                    'actual_rank', actual_rank, ...
                    'expected_rank', expected_rank); %#ok<AGROW>
                property_ok = false;
                return
            end

            for i = 1:length(property_definition.shape)
                dimension_definition = property_definition.shape(i);
                actual_size = actual_shape(i);

                if dimension_definition.is_fixed()
                    if actual_size ~= dimension_definition.value
                        report.bad_sizes{end+1} = struct( ...
                            'property_name', property_name, ...
                            'dimension_index', i, ...
                            'actual_size', actual_size, ...
                            'expected_size', dimension_definition.value); %#ok<AGROW>
                        property_ok = false;
                        return
                    end
                else
                    dimension_name = dimension_definition.value;
                    if ~isKey(dimension_bindings, dimension_name)
                        dimension_bindings(dimension_name) = {};
                    end
                    bindings = dimension_bindings(dimension_name);
                    bindings{end+1} = struct( ...
                        'property_name', property_name, ...
                        'size', actual_size); %#ok<AGROW>
                    dimension_bindings(dimension_name) = bindings;
                end
            end

            if ~isempty(property_definition.enumeration_name)
                valid_values = Validation.lookup_enumeration_values( ...
                    report, property_definition.enumeration_name);
                property_data = property_value(:);
                invalid_values = Validation.find_invalid_enumeration_values( ...
                    property_data, valid_values);
                if ~isempty(invalid_values)
                    report.invalid_enumerations{end+1} = struct( ...
                        'property_name', property_name, ...
                        'valid_values', {valid_values}, ...
                        'bad_values', {invalid_values}); %#ok<AGROW>
                    property_ok = false;
                    return
                end
            end

            if ~isempty(property_definition.regex)
                property_data = property_value(:);
                invalid_values = Validation.find_invalid_regex_values( ...
                    property_data, property_definition.regex);
                if ~isempty(invalid_values)
                    report.invalid_regexes{end+1} = struct( ...
                        'property_name', property_name, ...
                        'bad_values', {invalid_values}, ...
                        'pattern', property_definition.regex); %#ok<AGROW>
                    property_ok = false;
                    return
                end
            end

            if ~isempty(property_definition.value_constraints)
                property_data = property_value(:);
                for i_constraint = 1:length(property_definition.value_constraints)
                    constraint_name = property_definition.value_constraints{i_constraint};
                    message = Validation.check_value_constraint( ...
                        property_data, constraint_name, property_name);
                    if ~isempty(message)
                        report.invalid_value_constraints{end+1} = struct( ...
                            'property_name', property_name, ...
                            'constraint', constraint_name, ...
                            'message', message); %#ok<AGROW>
                        property_ok = false;
                        return
                    end
                end
            end
        end

        function [branch_ok, branch_dimension_bindings] = ...
                validate_choice_branch(dataset, branch_definitions, report, collect_failures)
            branch_ok = true;
            branch_dimension_bindings = containers.Map();

            for i = 1:length(branch_definitions)
                property_definition = branch_definitions(i);
                property_name = property_definition.name;
                property_value = dataset.(property_name);

                if isempty(property_value)
                    if ~property_definition.optional
                        branch_ok = false;
                    end
                    continue
                end

                local_report = ValidationReport(report.checked_specification);

                [property_ok, local_report, branch_dimension_bindings] = ...
                    Validation.validate_present_property_against_definition( ...
                        property_value, property_definition, local_report, branch_dimension_bindings);

                if ~property_ok
                    branch_ok = false;
                end
            end
        end

        function [branch_ok, branch_dimension_bindings, report] = ...
                validate_choice_branch_collecting(dataset, branch_definitions, report)
            branch_ok = true;
            branch_dimension_bindings = containers.Map();

            for i = 1:length(branch_definitions)
                property_definition = branch_definitions(i);
                property_name = property_definition.name;
                property_value = dataset.(property_name);

                if isempty(property_value)
                    if ~property_definition.optional
                        report.missing_properties{end+1} = struct( ...
                            'property_name', property_name); %#ok<AGROW>
                        branch_ok = false;
                    end
                    continue
                end

                [property_ok, report, branch_dimension_bindings] = ...
                    Validation.validate_present_property_against_definition( ...
                        property_value, property_definition, report, branch_dimension_bindings);

                if ~property_ok
                    branch_ok = false;
                end
            end
        end

        function destination = merge_dimension_bindings(destination, source)
            source_keys = keys(source);
            for i = 1:length(source_keys)
                dimension_name = source_keys{i};
                if ~isKey(destination, dimension_name)
                    destination(dimension_name) = {};
                end
                destination_bindings = destination(dimension_name);
                source_bindings = source(dimension_name);
                destination(dimension_name) = [destination_bindings, source_bindings];
            end
        end

        function inconsistent = find_inconsistent_dimensions(dimension_bindings)
            inconsistent = {};

            dimension_names = keys(dimension_bindings);
            for i = 1:length(dimension_names)
                dimension_name = dimension_names{i};
                bindings = dimension_bindings(dimension_name);
                sizes = cellfun(@(binding) binding.size, bindings);
                if length(unique(sizes)) > 1
                    inconsistent{end+1} = struct( ... %#ok<AGROW>
                        'dimension_name', dimension_name, ...
                        'bindings', {bindings});
                end
            end
        end

        function collapsed = collapse_dimension_bindings(dimension_bindings)
            collapsed = containers.Map();

            dimension_names = keys(dimension_bindings);
            for i = 1:length(dimension_names)
                dimension_name = dimension_names{i};
                bindings = dimension_bindings(dimension_name);
                sizes = cellfun(@(binding) binding.size, bindings);
                if ~isempty(sizes) && length(unique(sizes)) == 1
                    collapsed(dimension_name) = sizes(1);
                end
            end
        end

        function invalid_values = find_invalid_enumeration_values(property_data, valid_values)
            invalid_values = {};
            for i = 1:numel(property_data)
                value = Validation.normalize_scalar_value(property_data{i});
                if ~any(strcmp(valid_values, value))
                    invalid_values{end+1} = value; %#ok<AGROW>
                end
            end
            invalid_values = unique(invalid_values);
        end

        function invalid_values = find_invalid_regex_values(property_data, pattern)
            invalid_values = {};
            for i = 1:numel(property_data)
                value = Validation.normalize_scalar_value(property_data{i});
                if isempty(regexp(value, pattern, 'once'))
                    invalid_values{end+1} = value; %#ok<AGROW>
                end
            end
            invalid_values = unique(invalid_values);
        end

        function value = normalize_scalar_value(value)
        % Normalize a scalar-like value for validation checks.
        %
        % Parameters
        % ----------
        % value : any
        %     Scalar-like value from property data.
        %
        % Returns
        % -------
        % value : any
        %     Normalized scalar value suitable for comparison and display.
            if isstring(value)
                value = char(value);
            end
        end

        function valid_values = lookup_enumeration_values(report, enumeration_name)
            if isempty(report.resolved_specification)
                error('ValidationReport does not carry a resolved specification.')
            end
            valid_values = report.resolved_specification.enumerations(enumeration_name);
        end

        function message = check_value_constraint(property_data, constraint_name, property_name)
        % Evaluate one value constraint against property data.
        %
        % Parameters
        % ----------
        % property_data : array-like
        %     Property data array or scalar.
        % constraint_name : char
        %     Value-constraint name.
        % property_name : char
        %     Property name for diagnostic messages.
        %
        % Returns
        % -------
        % message : char
        %     Human-readable failure message if the constraint is
        %     violated, or empty if the constraint is satisfied.
            if strcmp(constraint_name, 'positive')
                if ~Validation.all_numeric_values_satisfy(property_data, @(x) x > 0)
                    message = sprintf('Property %s violates the positive constraint.', property_name);
                    return
                end
                message = '';
                return
            end

            if strcmp(constraint_name, 'nonnegative')
                if ~Validation.all_numeric_values_satisfy(property_data, @(x) x >= 0)
                    message = sprintf('Property %s violates the nonnegative constraint.', property_name);
                    return
                end
                message = '';
                return
            end

            if strcmp(constraint_name, 'finite')
                if ~Validation.all_numeric_values_satisfy(property_data, @isfinite)
                    message = sprintf('Property %s violates the finite constraint.', property_name);
                    return
                end
                message = '';
                return
            end

            if strcmp(constraint_name, 'increasing')
                values = Validation.flatten_numeric_values(property_data);
                if length(values) > 1 && ~all(values(2:end) >= values(1:end-1))
                    message = sprintf('Property %s violates the increasing constraint.', property_name);
                    return
                end
                message = '';
                return
            end

            if strcmp(constraint_name, 'strictly_increasing')
                values = Validation.flatten_numeric_values(property_data);
                if length(values) > 1 && ~all(values(2:end) > values(1:end-1))
                    message = sprintf('Property %s violates the strictly_increasing constraint.', property_name);
                    return
                end
                message = '';
                return
            end

            if strcmp(constraint_name, 'unique')
                values = Validation.flatten_comparable_values(property_data);

                if isempty(values)
                    message = '';
                    return
                end

                if all(cellfun(@(x) (isnumeric(x) || islogical(x)) && isscalar(x), values))
                    numeric_values = cell2mat(values(:));
                    if length(unique(numeric_values)) ~= length(numeric_values)
                        message = sprintf('Property %s violates the unique constraint.', property_name);
                        return
                    end
                else
                    string_values = cellfun(@Validation.scalar_to_comparable_string, ...
                        values(:), 'UniformOutput', false);
                    if length(unique(string_values)) ~= length(string_values)
                        message = sprintf('Property %s violates the unique constraint.', property_name);
                        return
                    end
                end

                message = '';
                return
            end

            
            if strcmp(constraint_name, 'nonempty')
                if ~Validation.is_nonempty_value(property_data)
                    message = sprintf('Property %s violates the nonempty constraint.', property_name);
                    return
                end
                message = '';
                return
            end

            error('Unknown value constraint "%s".', constraint_name);
        end

        function out = scalar_to_comparable_string(value)
        % Convert a scalar value to a comparable string representation.
        %
        % Parameters
        % ----------
        % value : any
        %     Scalar value to convert.
        %
        % Returns
        % -------
        % out : char
        %     Comparable string representation.
            value = Validation.normalize_scalar_value(value);

            if ischar(value)
                out = value;
            elseif isstring(value)
                out = char(value);
            elseif isnumeric(value) || islogical(value)
                out = num2str(value);
            else
                out = char(string(value));
            end
        end

        function out = all_numeric_values_satisfy(property_data, predicate)
        % Return whether all numeric values satisfy a predicate.
        %
        % Parameters
        % ----------
        % property_data : array-like
        %     Property data array or scalar.
        % predicate : function_handle
        %     Predicate applied elementwise to numeric values.
        %
        % Returns
        % -------
        % out : logical
        %     True if all numeric values satisfy the predicate.
            values = Validation.flatten_numeric_values(property_data);
            if isempty(values)
                out = true;
                return
            end
            out = all(predicate(values));
        end

        function values = flatten_numeric_values(property_data)
        % Flatten property data into a numeric vector.
        %
        % Parameters
        % ----------
        % property_data : array-like
        %     Property data array or scalar.
        %
        % Returns
        % -------
        % values : numeric array
        %     Flattened numeric vector.
            if iscell(property_data)
                normalized = cellfun(@Validation.normalize_scalar_value, property_data, ...
                    'UniformOutput', false);
                values = cell2mat(normalized(:));
            else
                values = property_data(:);
            end
        end

        function values = flatten_comparable_values(property_data)
        % Flatten property data into a cell array of comparable scalar values.
        %
        % Parameters
        % ----------
        % property_data : array-like
        %     Property data array or scalar.
        %
        % Returns
        % -------
        % values : cell array
        %     Flattened comparable scalar values.
            if iscell(property_data)
                values = cellfun(@Validation.normalize_scalar_value, property_data(:), ...
                    'UniformOutput', false);
            else
                raw_values = num2cell(property_data(:));
                values = cellfun(@Validation.normalize_scalar_value, raw_values, ...
                    'UniformOutput', false);
            end
        end

        function out = is_nonempty_value(property_data)
        % Return whether property data satisfies the nonempty constraint.
        %
        % Parameters
        % ----------
        % property_data : array-like
        %     Property data array or scalar.
        %
        % Returns
        % -------
        % out : logical
        %     True if the value should be considered nonempty.
            if isempty(property_data)
                out = false;
                return
            end

            if iscell(property_data)
                for i = 1:numel(property_data)
                    value = Validation.normalize_scalar_value(property_data{i});
                    if ischar(value) || isstring(value)
                        if strlength(string(value)) == 0
                            out = false;
                            return
                        end
                    elseif isnumeric(value)
                        if isempty(value)
                            out = false;
                            return
                        end
                    end
                end
                out = true;
                return
            end

            if ischar(property_data) || isstring(property_data)
                out = strlength(string(property_data)) > 0;
                return
            end

            out = ~isempty(property_data);
        end

        function failures = evaluate_constraint_rules(dataset, resolved_specification, present_properties) %#ok<INUSD>
        % Evaluate cross-property constraint rules.
        %
        % Parameters
        % ----------
        % dataset : escdf_dataset
        %     Dataset object being validated.
        % resolved_specification : ResolvedSpecification
        %     Effective resolved specification.
        % present_properties : cell array of char
        %     Property names currently present on the dataset.
        %
        % Returns
        % -------
        % failures : cell array
        %     Constraint-failure records.
            failures = {};

            for i = 1:length(resolved_specification.constraints)
                rule = resolved_specification.constraints(i);

                if strcmp(rule.kind, 'requires')
                    failure = Validation.evaluate_requires_rule(rule, present_properties);
                    if ~isempty(failure)
                        failures{end+1} = failure; %#ok<AGROW>
                    end
                else
                    % Future constraint kinds will be implemented later.
                    continue
                end
            end
        end

        function failure = evaluate_requires_rule(rule, present_properties)
        % Evaluate one requires constraint rule.
        %
        % Parameters
        % ----------
        % rule : ConstraintRule
        %     Requires rule to evaluate.
        % present_properties : cell array of char
        %     Property names currently present on the dataset.
        %
        % Returns
        % -------
        % failure : struct or empty
        %     Constraint-failure record if violated, otherwise empty.
            subjects_present = rule.subject_properties( ...
                ismember(rule.subject_properties, present_properties));

            if isempty(subjects_present)
                failure = [];
                return
            end

            missing_targets = rule.target_properties( ...
                ~ismember(rule.target_properties, present_properties));

            if isempty(missing_targets)
                failure = [];
                return
            end

            failure = struct( ...
                'constraint_kind', 'requires', ...
                'subject_properties', {rule.subject_properties}, ...
                'target_properties', {rule.target_properties}, ...
                'missing_target_properties', {missing_targets}, ...
                'message', sprintf( ...
                    'Constraint requires failed: present subject properties %s require target properties %s.', ...
                    strjoin(subjects_present, ', '), ...
                    strjoin(missing_targets, ', ')));
        end

    end
end