<script>
/*
 * The following component has several commented lines, this is because we are refactoring them piece by piece on several mrs
 * For a complete overview of the plan please check: https://gitlab.com/gitlab-org/gitlab/-/issues/330846
 * This work is behind feature flag: https://gitlab.com/gitlab-org/gitlab/-/issues/341136
 */
// import { GlEmptyState, GlLink, GlSprintf } from '@gitlab/ui';
import createFlash from '~/flash';
import { historyReplaceState } from '~/lib/utils/common_utils';
import { s__ } from '~/locale';
import { DELETE_PACKAGE_SUCCESS_MESSAGE } from '~/packages/list/constants';
import { SHOW_DELETE_SUCCESS_ALERT } from '~/packages/shared/constants';
import getPackagesQuery from '~/packages_and_registries/package_registry/graphql/queries/get_packages.query.graphql';
import {
  PROJECT_RESOURCE_TYPE,
  GROUP_RESOURCE_TYPE,
  LIST_QUERY_DEBOUNCE_TIME,
} from '~/packages_and_registries/package_registry/constants';
import PackageTitle from './package_title.vue';
import PackageSearch from './package_search.vue';
// import PackageList from './packages_list.vue';

export default {
  components: {
    // GlEmptyState,
    // GlLink,
    // GlSprintf,
    // PackageList,
    PackageTitle,
    PackageSearch,
  },
  inject: [
    'packageHelpUrl',
    'emptyListIllustration',
    'emptyListHelpUrl',
    'isGroupPage',
    'fullPath',
  ],
  data() {
    return {
      packages: {},
      sort: '',
      filters: {},
    };
  },
  apollo: {
    packages: {
      query: getPackagesQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data[this.graphqlResource].packages;
      },
      debounce: LIST_QUERY_DEBOUNCE_TIME,
    },
  },
  computed: {
    queryVariables() {
      return {
        isGroupPage: this.isGroupPage,
        fullPath: this.fullPath,
        sort: this.isGroupPage ? undefined : this.sort,
        groupSort: this.isGroupPage ? this.sort : undefined,
        packageName: this.filters?.packageName,
        packageType: this.filters?.packageType,
      };
    },
    graphqlResource() {
      return this.isGroupPage ? GROUP_RESOURCE_TYPE : PROJECT_RESOURCE_TYPE;
    },
    packagesCount() {
      return this.packages?.count;
    },
    hasFilters() {
      return this.filters.packageName && this.filters.packageType;
    },
    emptyStateTitle() {
      return this.emptySearch
        ? this.$options.i18n.emptyPageTitle
        : this.$options.i18n.noResultsTitle;
    },
  },
  mounted() {
    this.checkDeleteAlert();
  },
  methods: {
    checkDeleteAlert() {
      const urlParams = new URLSearchParams(window.location.search);
      const showAlert = urlParams.get(SHOW_DELETE_SUCCESS_ALERT);
      if (showAlert) {
        // to be refactored to use gl-alert
        createFlash({ message: DELETE_PACKAGE_SUCCESS_MESSAGE, type: 'notice' });
        const cleanUrl = window.location.href.split('?')[0];
        historyReplaceState(cleanUrl);
      }
    },
    handleSearchUpdate({ sort, filters }) {
      this.sort = sort;
      this.filters = { ...filters };
    },
  },
  i18n: {
    widenFilters: s__('PackageRegistry|To widen your search, change or remove the filters above.'),
    emptyPageTitle: s__('PackageRegistry|There are no packages yet'),
    noResultsTitle: s__('PackageRegistry|Sorry, your filter produced no results'),
    noResultsText: s__(
      'PackageRegistry|Learn how to %{noPackagesLinkStart}publish and share your packages%{noPackagesLinkEnd} with GitLab.',
    ),
  },
};
</script>

<template>
  <div>
    <package-title :help-url="packageHelpUrl" :count="packagesCount" />
    <package-search @update="handleSearchUpdate" />

    <!-- <package-list @page:changed="onPageChanged" @package:delete="onPackageDeleteRequest">
      <template #empty-state>
        <gl-empty-state :title="emptyStateTitle" :svg-path="emptyListIllustration">
          <template #description>
            <gl-sprintf v-if="hasFilters" :message="$options.i18n.widenFilters" />
            <gl-sprintf v-else :message="$options.i18n.noResultsText">
              <template #noPackagesLink="{ content }">
                <gl-link :href="emptyListHelpUrl" target="_blank">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </template>
        </gl-empty-state>
      </template>
    </package-list> -->
  </div>
</template>
