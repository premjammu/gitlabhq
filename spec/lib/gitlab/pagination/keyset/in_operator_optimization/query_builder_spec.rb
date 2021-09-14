# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder do
  let_it_be(:two_weeks_ago) { 2.weeks.ago }
  let_it_be(:three_weeks_ago) { 3.weeks.ago }
  let_it_be(:four_weeks_ago) { 4.weeks.ago }
  let_it_be(:five_weeks_ago) { 5.weeks.ago }

  let_it_be(:top_level_group) { create(:group) }
  let_it_be(:sub_group_1) { create(:group, parent: top_level_group) }
  let_it_be(:sub_group_2) { create(:group, parent: top_level_group) }
  let_it_be(:sub_sub_group_1) { create(:group, parent: sub_group_2) }

  let_it_be(:project_1) { create(:project, group: top_level_group) }
  let_it_be(:project_2) { create(:project, group: top_level_group) }

  let_it_be(:project_3) { create(:project, group: sub_group_1) }
  let_it_be(:project_4) { create(:project, group: sub_group_2) }

  let_it_be(:project_5) { create(:project, group: sub_sub_group_1) }

  let_it_be(:issues) do
    [
      create(:issue, project: project_1, created_at: three_weeks_ago, relative_position: 5),
      create(:issue, project: project_1, created_at: two_weeks_ago),
      create(:issue, project: project_2, created_at: two_weeks_ago, relative_position: 15),
      create(:issue, project: project_2, created_at: two_weeks_ago),
      create(:issue, project: project_3, created_at: four_weeks_ago),
      create(:issue, project: project_4, created_at: five_weeks_ago, relative_position: 10),
      create(:issue, project: project_5, created_at: four_weeks_ago)
    ]
  end

  shared_examples 'correct ordering examples' do
    let(:iterator) do
      Gitlab::Pagination::Keyset::Iterator.new(
        scope: scope.limit(batch_size),
        in_operator_optimization_options: in_operator_optimization_options
      )
    end

    it 'returns records in correct order' do
      all_records = []
      iterator.each_batch(of: batch_size) do |records|
        all_records.concat(records)
      end

      expect(all_records).to eq(expected_order)
    end
  end

  context 'when ordering by issues.id DESC' do
    let(:scope) { Issue.order(id: :desc) }
    let(:expected_order) { issues.sort_by(&:id).reverse }

    let(:in_operator_optimization_options) do
      {
        array_scope: Project.where(namespace_id: top_level_group.self_and_descendants.select(:id)).select(:id),
        array_mapping_scope: -> (id_expression) { Issue.where(Issue.arel_table[:project_id].eq(id_expression)) },
        finder_query: -> (id_expression) { Issue.where(Issue.arel_table[:id].eq(id_expression)) }
      }
    end

    context 'when iterating records one by one' do
      let(:batch_size) { 1 }

      it_behaves_like 'correct ordering examples'
    end

    context 'when iterating records with LIMIT 3' do
      let(:batch_size) { 3 }

      it_behaves_like 'correct ordering examples'
    end

    context 'when loading records at once' do
      let(:batch_size) { issues.size + 1 }

      it_behaves_like 'correct ordering examples'
    end
  end

  context 'when ordering by issues.relative_position DESC NULLS LAST, id DESC' do
    let(:scope) { Issue.order(order) }
    let(:expected_order) { scope.to_a }

    let(:order) do
      # NULLS LAST ordering requires custom Order object for keyset pagination:
      # https://docs.gitlab.com/ee/development/database/keyset_pagination.html#complex-order-configuration
      Gitlab::Pagination::Keyset::Order.build([
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: :relative_position,
          column_expression: Issue.arel_table[:relative_position],
          order_expression: Gitlab::Database.nulls_last_order('relative_position', :desc),
          reversed_order_expression: Gitlab::Database.nulls_first_order('relative_position', :asc),
          order_direction: :desc,
          nullable: :nulls_last,
          distinct: false
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: :id,
          order_expression: Issue.arel_table[:id].desc,
          nullable: :not_nullable,
          distinct: true
        )
      ])
    end

    let(:in_operator_optimization_options) do
      {
        array_scope: Project.where(namespace_id: top_level_group.self_and_descendants.select(:id)).select(:id),
        array_mapping_scope: -> (id_expression) { Issue.where(Issue.arel_table[:project_id].eq(id_expression)) },
        finder_query: -> (_relative_position_expression, id_expression) { Issue.where(Issue.arel_table[:id].eq(id_expression)) }
      }
    end

    context 'when iterating records one by one' do
      let(:batch_size) { 1 }

      it_behaves_like 'correct ordering examples'
    end

    context 'when iterating records with LIMIT 3' do
      let(:batch_size) { 3 }

      it_behaves_like 'correct ordering examples'
    end
  end

  context 'when ordering by issues.created_at DESC, issues.id ASC' do
    let(:scope) { Issue.order(created_at: :desc, id: :asc) }
    let(:expected_order) { issues.sort_by { |issue| [issue.created_at.to_f * -1, issue.id] } }

    let(:in_operator_optimization_options) do
      {
        array_scope: Project.where(namespace_id: top_level_group.self_and_descendants.select(:id)).select(:id),
        array_mapping_scope: -> (id_expression) { Issue.where(Issue.arel_table[:project_id].eq(id_expression)) },
        finder_query: -> (_created_at_expression, id_expression) { Issue.where(Issue.arel_table[:id].eq(id_expression)) }
      }
    end

    context 'when iterating records one by one' do
      let(:batch_size) { 1 }

      it_behaves_like 'correct ordering examples'
    end

    context 'when iterating records with LIMIT 3' do
      let(:batch_size) { 3 }

      it_behaves_like 'correct ordering examples'
    end

    context 'when loading records at once' do
      let(:batch_size) { issues.size + 1 }

      it_behaves_like 'correct ordering examples'
    end
  end

  context 'pagination support' do
    let(:scope) { Issue.order(id: :desc) }
    let(:expected_order) { issues.sort_by(&:id).reverse }

    let(:options) do
      {
        scope: scope,
        array_scope: Project.where(namespace_id: top_level_group.self_and_descendants.select(:id)).select(:id),
        array_mapping_scope: -> (id_expression) { Issue.where(Issue.arel_table[:project_id].eq(id_expression)) },
        finder_query: -> (id_expression) { Issue.where(Issue.arel_table[:id].eq(id_expression)) }
      }
    end

    context 'offset pagination' do
      subject(:optimized_scope) { described_class.new(**options).execute }

      it 'paginates the scopes' do
        first_page = optimized_scope.page(1).per(2)
        expect(first_page).to eq(expected_order[0...2])

        second_page = optimized_scope.page(2).per(2)
        expect(second_page).to eq(expected_order[2...4])

        third_page = optimized_scope.page(3).per(2)
        expect(third_page).to eq(expected_order[4...6])
      end
    end

    context 'keyset pagination' do
      def paginator(cursor = nil)
        scope.keyset_paginate(cursor: cursor, per_page: 2, keyset_order_options: options)
      end

      it 'paginates correctly' do
        first_page = paginator.records
        expect(first_page).to eq(expected_order[0...2])

        cursor_for_page_2 = paginator.cursor_for_next_page

        second_page = paginator(cursor_for_page_2).records
        expect(second_page).to eq(expected_order[2...4])

        cursor_for_page_3 = paginator(cursor_for_page_2).cursor_for_next_page

        third_page = paginator(cursor_for_page_3).records
        expect(third_page).to eq(expected_order[4...6])
      end
    end
  end

  it 'raises error when unsupported scope is passed' do
    scope = Issue.order(Issue.arel_table[:id].lower.desc)

    options = {
      scope: scope,
      array_scope: Project.where(namespace_id: top_level_group.self_and_descendants.select(:id)).select(:id),
      array_mapping_scope: -> (id_expression) { Issue.where(Issue.arel_table[:project_id].eq(id_expression)) },
      finder_query: -> (id_expression) { Issue.where(Issue.arel_table[:id].eq(id_expression)) }
    }

    expect { described_class.new(**options).execute }.to raise_error(/The order on the scope does not support keyset pagination/)
  end
end
