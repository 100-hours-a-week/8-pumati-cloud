# ------------------------------------------------------------
# 인스턴스 변수
# ------------------------------------------------------------
variable "instance_type" {
    type = string
    description = "인스턴스 타입 (예: t2.micro)"
    default = "t2.micro"
}

variable "instance_ami_linux" {
    type = string
    description = "Linux AMI ID"
    default = "ami-0d5bb3742db8fc264"
}

variable "instance_key_name" {
    type = string
    description = "키페어 이름"
    default = "pumati-full-master"
}

# ------------------------------------------------------------
# 스토리지 변수
# ------------------------------------------------------------
variable "root_volume_size" {
    type = number
    description = "루트 볼륨 크기 (GB)"
    default = 20
}

variable "root_volume_type" {
    type = string
    description = "루트 볼륨 타입 (gp2, gp3, io1 등)"
    default = "gp3"
}

