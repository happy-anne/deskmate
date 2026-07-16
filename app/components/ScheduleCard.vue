<script setup lang="ts">
import type { EventView, SlotView } from '~/composables/useSchedule'
import type { Schedule } from '~/types/db'

const props = defineProps<{
  view: EventView
  meId: string | null
}>()
const emit = defineEmits<{ cell: [Schedule] }>()

const isMe = (c: Schedule) => !!props.meId && c.user_id === props.meId
</script>

<template>
  <section class="card overflow-hidden">
    <!-- Week header -->
    <div class="flex items-baseline gap-2 border-b border-grey-100 px-4 py-3">
      <span class="text-subtitle text-ink">{{ view.event.week_label }}</span>
      <span class="text-body text-grey-500 tnum">{{
        shortDate(view.event.date)
      }}</span>
      <span
        v-if="view.event.type && view.event.type !== '토요일'"
        class="badge badge-grey ml-auto"
        >{{ view.event.type }}</span
      >
    </div>

    <!-- Slots -->
    <div class="divide-y divide-grey-100">
      <div
        v-for="slot in view.slots"
        :key="slot.slot_no"
        class="flex items-stretch gap-3 px-4 py-2.5"
      >
        <div class="flex w-[6rem] shrink-0 items-center gap-[8px] py-1">
          <div class="text-subtitle text-ink">{{ slot.slot_no }}</div>
          <div class="whitespace-nowrap text-caption text-grey-500 tnum">
            {{ slot.start }}~{{ slot.end }}
          </div>
        </div>

        <div class="grid flex-1 grid-cols-2 gap-2">
          <button
            v-for="cell in slot.cells"
            :key="cell.id"
            class="flex min-h-[52px] flex-col items-start justify-center rounded-lg border px-3 py-2 text-left transition-colors active:scale-[0.98]"
            :class="
              isMe(cell)
                ? 'border-primary bg-primary/[0.08]'
                : 'border-grey-200 bg-white active:bg-grey-50'
            "
            @click="emit('cell', cell)"
          >
            <div class="flex w-full items-center gap-1">
              <span
                class="whitespace-nowrap text-body-lg"
                :class="isMe(cell) ? 'font-bold text-primary-hover' : 'font-medium text-ink'"
              >
                {{ cell.user?.name ?? '미배정' }}
              </span>
              <AppIcon
                v-if="cell.is_pinned"
                name="pin"
                :size="14"
                class="shrink-0 text-grey-400"
              />
            </div>
            <span
              v-if="cell.is_changed"
              class="badge badge-yellow mt-1"
            >변경됨</span>
          </button>
        </div>
      </div>
    </div>
  </section>
</template>
