static int sensor_g_exp(struct v4l2_subdev *sd, __s32 *value);

static int sensor_s_exp(struct v4l2_subdev *sd, unsigned int exp_val);

static int sensor_g_gain(struct v4l2_subdev *sd, __s32 *value);

static int sensor_s_gain(struct v4l2_subdev *sd, unsigned int gain_val);

static int sensor_s_exp_gain(struct v4l2_subdev *sd, struct sensor_exp_gain *exp_gain);

static int sensor_s_streamon(struct v4l2_subdev *sd);

static int sensor_s_sw_stby(struct v4l2_subdev *sd, int on_off);

static int sensor_power(struct v4l2_subdev *sd, int on);

static int sensor_detect(struct v4l2_subdev *sd);

static int sensor_init(struct v4l2_subdev *sd, u32 val);

static long sensor_ioctl(struct v4l2_subdev *sd, unsigned int cmd, void *arg);

static int sensor_g_mbus_config(struct v4l2_subdev *sd, unsigned int pad,
				struct v4l2_mbus_config *cfg);

static int sensor_g_ctrl(struct v4l2_ctrl *ctrl);

static int sensor_s_ctrl(struct v4l2_ctrl *ctrl);

static int sensor_reg_init(struct sensor_info *info);

static int sensor_s_stream(struct v4l2_subdev *sd, int enable);

static int sensor_init_controls(struct v4l2_subdev *sd,
				const struct v4l2_ctrl_ops *ops);

static int sensor_probe(struct i2c_client *client,
			const struct i2c_device_id *id);

static int sensor_remove(struct i2c_client *client);