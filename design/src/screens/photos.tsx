import type { ReactNode } from 'react'

import { light, radius, typography } from '../theme'

const editorInk = '#0E1311'

/**
 * A stand-in for a picked photo: this surface ships no image assets, so the
 * "photo" is drawn with gradients and reads as a portrait at a glance.
 */
function Portrait() {
  return (
    <div
      className="relative h-full w-full overflow-hidden"
      style={{ background: 'linear-gradient(165deg, #8A9C90 0%, #55695C 48%, #2B3A32 100%)' }}
    >
      <span
        className="absolute left-1/2 top-[24%] h-[32%] w-[34%] -translate-x-1/2 rounded-[48%]"
        style={{ background: '#D9C7B5' }}
      />
      <span
        className="absolute bottom-0 left-1/2 h-[36%] w-[64%] -translate-x-1/2 rounded-t-[50%]"
        style={{ background: '#465D4F' }}
      />
    </div>
  )
}

function EditorFrame({
  title,
  sub,
  background = editorInk,
  children,
}: {
  title: string
  sub?: string
  background?: string
  children: ReactNode
}) {
  return (
    <figure className="w-[390px] shrink-0">
      <figcaption className="mb-2">
        <span className="block text-[13px] font-bold" style={{ color: light.textPrimary }}>
          {title}
        </span>
        {sub ? (
          <span className="block text-[11px]" style={{ color: light.textSecondary }}>
            {sub}
          </span>
        ) : null}
      </figcaption>
      <div className="overflow-hidden" style={{ background, border: `1px solid ${light.border}` }}>
        <div className="flex h-[780px] flex-col">{children}</div>
      </div>
    </figure>
  )
}

function Bracket({ className }: { className: string }) {
  return <span className={`absolute h-5 w-5 ${className}`} style={{ borderColor: '#FFFFFF' }} />
}

/**
 * The last step before upload: a 1:1 crop, because every avatar in the app is
 * clipped to a circle. The circle guide shows the result the user will get.
 */
export function CropPhotoScreen() {
  return (
    <EditorFrame title="Crop photo" sub="Picked photo, before anything is uploaded">
      <div className="flex h-14 shrink-0 items-center gap-2 px-2">
        <span className="grid h-10 w-10 place-items-center text-[18px]" style={{ color: '#FFFFFF' }}>
          ✕
        </span>
        <span className="flex-1 text-[16px] font-bold" style={{ color: '#FFFFFF' }}>
          Crop photo
        </span>
        <span className="w-12" />
      </div>

      <div className="relative flex-1 overflow-hidden">
        <Portrait />

        {/* box-shadow dims everything outside the crop square, so the square
            itself stays at full brightness. */}
        <div
          className="absolute top-1/2 left-1/2 aspect-square w-[350px] -translate-x-1/2 -translate-y-1/2"
          style={{ boxShadow: '0 0 0 9999px rgba(0, 0, 0, 0.62)' }}
        >
          <span className="absolute inset-y-0 left-1/3 w-px bg-white/20" />
          <span className="absolute inset-y-0 left-2/3 w-px bg-white/20" />
          <span className="absolute inset-x-0 top-1/3 h-px bg-white/20" />
          <span className="absolute inset-x-0 top-2/3 h-px bg-white/20" />
          <span className="absolute inset-0 rounded-full border border-white/45" />
          <Bracket className="top-1 left-1 border-t-2 border-l-2" />
          <Bracket className="top-1 right-1 border-t-2 border-r-2" />
          <Bracket className="bottom-1 left-1 border-b-2 border-l-2" />
          <Bracket className="right-1 bottom-1 border-r-2 border-b-2" />
        </div>
      </div>

      <div className="shrink-0 px-5 pb-4">
        <p className="text-center text-[12px]" style={{ color: 'rgba(255, 255, 255, 0.6)' }}>
          Drag to reposition · pinch to zoom
        </p>
        <div className="mt-3 flex items-center gap-3">
          <span className="py-3 text-[13px] font-bold" style={{ color: 'rgba(255, 255, 255, 0.3)' }}>
            Reset
          </span>
          <span
            className="flex-1 rounded-[14px] py-3.5 text-center text-[15px] font-bold"
            style={{ background: light.accent, color: '#2A1613' }}
          >
            Use photo
          </span>
        </div>
      </div>
    </EditorFrame>
  )
}

/** A photo that is already saved opens full screen; nothing is re-encoded. */
export function PhotoViewerScreen() {
  return (
    <EditorFrame title="Photo viewer" sub="Tap an avatar that already has a photo" background="#000000">
      <div className="relative flex-1">
        <Portrait />
        <span
          className="absolute top-3 left-3 grid h-10 w-10 place-items-center rounded-full text-[16px]"
          style={{ background: 'rgba(0, 0, 0, 0.45)', color: '#FFFFFF' }}
        >
          ✕
        </span>
      </div>
    </EditorFrame>
  )
}

function SheetRow({ icon, title, subtitle }: { icon: string; title: string; subtitle: string }) {
  return (
    <div className="flex items-center gap-3.5 px-1 py-2.5">
      <span
        className="grid h-11 w-11 shrink-0 place-items-center rounded-full text-[16px]"
        style={{ background: light.softGreen }}
      >
        {icon}
      </span>
      <span className="flex-1">
        <b className="block text-[14px]" style={{ color: light.textPrimary }}>
          {title}
        </b>
        <span className="block text-[12px]" style={{ color: light.textSecondary }}>
          {subtitle}
        </span>
      </span>
      <span className="text-[14px]" style={{ color: light.textSecondary }}>
        ›
      </span>
    </div>
  )
}

/** Camera or library, then the crop editor. */
export function PhotoSourceSheet() {
  return (
    <figure className="w-[390px] shrink-0">
      <figcaption className="mb-2">
        <span className="block text-[13px] font-bold" style={{ color: light.textPrimary }}>
          Photo source sheet
        </span>
        <span className="block text-[11px]" style={{ color: light.textSecondary }}>
          Opened by Add photo or by tapping an empty avatar
        </span>
      </figcaption>
      <div
        className="relative h-[780px] overflow-hidden"
        style={{ background: light.background, border: `1px solid ${light.border}` }}
      >
        <div className="px-5 py-5">
          <p className={typography.label} style={{ color: light.textSecondary }}>
            Add birthday
          </p>
          <h1 className={`mt-2 ${typography.display}`} style={{ color: light.textPrimary }}>
            Add birthday
          </h1>
          <div className="mt-5 flex flex-col items-center">
            <span
              className="grid h-[84px] w-[84px] place-items-center rounded-full text-[27px] font-bold"
              style={{ background: light.avatarTints[0], color: light.textPrimary }}
            >
              ?
            </span>
            <span className="mt-2.5 text-[13px] font-bold" style={{ color: light.accentText }}>
              Add photo
            </span>
          </div>
          <div className="mt-4 space-y-3">
            <div
              className="h-[52px] rounded-[14px]"
              style={{ background: light.surface, border: `1px solid ${light.border}` }}
            />
            <div
              className="h-[52px] rounded-[14px]"
              style={{ background: light.surface, border: `1px solid ${light.border}` }}
            />
            <div
              className="h-[52px] rounded-[14px]"
              style={{ background: light.surface, border: `1px solid ${light.border}` }}
            />
          </div>
        </div>

        <div className="absolute inset-0" style={{ background: 'rgba(0, 0, 0, 0.4)' }} />

        <div
          className="absolute inset-x-0 bottom-0 px-5 pt-2 pb-5"
          style={{
            background: light.surface,
            borderTopLeftRadius: radius.sheet,
            borderTopRightRadius: radius.sheet,
          }}
        >
          <span className="mx-auto block h-1 w-10 rounded-full" style={{ background: light.border }} />
          <p className="mt-4 text-[16px] font-bold" style={{ color: light.textPrimary }}>
            Add a photo
          </p>
          <p className="mt-1 text-[12px]" style={{ color: light.textSecondary }}>
            You can crop it before it is saved.
          </p>
          <div className="mt-2 space-y-1">
            <SheetRow icon="📷" title="Take a photo" subtitle="Open the camera" />
            <SheetRow icon="🖼️" title="Choose from library" subtitle="Use a photo on this device" />
          </div>
          <p className="mt-1 py-3 text-center text-[13px] font-bold" style={{ color: light.textSecondary }}>
            Cancel
          </p>
        </div>
      </div>
    </figure>
  )
}
