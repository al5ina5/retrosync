export default function Layout({ children }: { children: React.ReactNode }) {
    return (
        <div className="max-w-3xl mx-auto p-6 py-12">
            <div className="space-y-12">{children}</div>
            {/* Space for bottom mobile-only nav. */}
            <div className="md:hidden h-[42px]"></div>
        </div>
    );
}