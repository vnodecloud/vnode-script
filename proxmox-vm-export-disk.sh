#!/bin/bash

read -p "Nhập VMID của máy ảo cần export disk: " vmid

# Kiểm tra VMID có tồn tại không
if ! qm config "$vmid" &>/dev/null; then
    echo "Lỗi: VMID $vmid không tồn tại trên hệ thống!"
    exit 1
fi

# Tự động tìm ổ đĩa chính (ưu tiên scsi0, virtio0, sata0, ide0)
DISK_KEY=""
for key in scsi0 virtio0 sata0 ide0; do
    if qm config "$vmid" | grep -q "^$key:"; then
        DISK_KEY="$key"
        break
    fi
done

if [ -z "$DISK_KEY" ]; then
    echo "Lỗi: Không tìm thấy ổ đĩa nào cho VMID $vmid!"
    exit 1
fi

# Lấy Volume ID của ổ đĩa
VOLID=$(qm config "$vmid" | grep "^$DISK_KEY:" | sed -E 's/.*: *([^,]+).*/\1/')
echo "Đang xử lý ổ đĩa $DISK_KEY (Volume ID: $VOLID)..."

# Lấy đường dẫn thực tế của ổ đĩa thông qua pvesm
SRC_PATH=$(pvesm path "$VOLID" 2>/dev/null)
DEST="/root/disk-${vmid}-exported.qcow2"

if [ -n "$SRC_PATH" ] && [ -e "$SRC_PATH" ]; then
    echo "Đang chuyển đổi và xuất file qcow2 từ: $SRC_PATH"
    qemu-img convert -O qcow2 "$SRC_PATH" "$DEST"
else
    echo "Đang chuyển đổi trực tiếp Volume ID sang file qcow2..."
    qemu-img convert -O qcow2 "$VOLID" "$DEST"
fi

if [ $? -eq 0 ]; then
    echo "Thành công! File qcow2 được lưu tại: $DEST"
    ls -lh "$DEST"
else
    echo "Lỗi: Quá trình export disk thất bại!"
    exit 1
fi
